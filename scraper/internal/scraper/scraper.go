package scraper

import (
	"context"
	"crypto/sha1"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
)

var pdfLinkPattern = regexp.MustCompile(`(?:https?:)?//letak\.spar\.si/[^\s"'<>\\]+/getPdf\.ashx(?:\?[^\s"'<>\\]*)?|/[^\s"'<>\\]+/getPdf\.ashx(?:\?[^\s"'<>\\]*)?`)

func GetPageSource(targetURL string) (string, error) {
	return GetPageSourceWithClient(context.Background(), targetURL, newHTTPClient())
}

func GetPageSourceWithClient(ctx context.Context, targetURL string, client *http.Client) (string, error) {
	if client == nil {
		client = newHTTPClient()
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, targetURL, nil)
	if err != nil {
		return "", fmt.Errorf("create request: %w", err)
	}
	setBrowserHeaders(req, "https://www.spar.si/", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")

	resp, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("fetch page: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < http.StatusOK || resp.StatusCode >= http.StatusMultipleChoices {
		return "", fmt.Errorf("fetch %s: unexpected status code: %d", targetURL, resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("read response body: %w", err)
	}

	return string(body), nil
}

func ExtractSparPDFLinks(pageSource string) []string {
	matches := pdfLinkPattern.FindAllString(pageSource, -1)
	if len(matches) == 0 {
		return nil
	}

	seen := make(map[string]struct{}, len(matches))
	links := make([]string, 0, len(matches))

	for _, m := range matches {
		link := strings.ReplaceAll(m, `\/`, `/`)
		if strings.HasPrefix(link, "//") {
			link = "https:" + link
		} else if strings.HasPrefix(link, "/") {
			link = "https://letak.spar.si" + link
		}

		link = strings.TrimRight(link, ".,)")
		if _, ok := seen[link]; ok {
			continue
		}
		seen[link] = struct{}{}
		links = append(links, link)
	}

	sort.Strings(links)
	return links
}

func FetchSparPDFLinksFromPage(pageURL string) ([]string, error) {
	body, err := GetPageSource(pageURL)
	if err != nil {
		return nil, err
	}
	return ExtractSparPDFLinks(body), nil
}

func DownloadCatalogPDFs(pageURL, outputRoot, storeName string) ([]string, error) {
	links, err := FetchSparPDFLinksFromPage(pageURL)
	if err != nil {
		return nil, err
	}
	if len(links) == 0 {
		return nil, fmt.Errorf("no PDF links found")
	}

	outDir := filepath.Join(outputRoot, storeName)
	if err := os.MkdirAll(outDir, 0o755); err != nil {
		return nil, fmt.Errorf("create output directory: %w", err)
	}

	client := newHTTPClient()
	saved := make([]string, 0, len(links))

	for _, link := range links {
		savedPath, err := downloadFile(client, link, outDir)
		if err != nil {
			return saved, err
		}
		saved = append(saved, savedPath)
	}

	return saved, nil
}

func newHTTPClient() *http.Client {
	return &http.Client{Timeout: 3 * time.Minute}
}

func downloadFile(client *http.Client, targetURL, outDir string) (string, error) {
	req, err := http.NewRequest(http.MethodGet, targetURL, nil)
	if err != nil {
		return "", fmt.Errorf("create download request for %s: %w", targetURL, err)
	}
	setBrowserHeaders(req, catalogReferer(targetURL), "application/pdf,application/octet-stream;q=0.9,*/*;q=0.8")

	resp, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("download %s: %w", targetURL, err)
	}

	if resp.StatusCode == http.StatusForbidden {
		resp.Body.Close()

		retryReq, reqErr := http.NewRequest(http.MethodGet, targetURL, nil)
		if reqErr != nil {
			return "", fmt.Errorf("create retry request for %s: %w", targetURL, reqErr)
		}
		setBrowserHeaders(retryReq, "https://www.spar.si/letak", "application/pdf,application/octet-stream;q=0.9,*/*;q=0.8")

		resp, err = client.Do(retryReq)
		if err != nil {
			return "", fmt.Errorf("retry download %s: %w", targetURL, err)
		}
	}
	defer resp.Body.Close()

	if resp.StatusCode < http.StatusOK || resp.StatusCode >= http.StatusMultipleChoices {
		return "", fmt.Errorf("download %s: unexpected status code: %d", targetURL, resp.StatusCode)
	}

	fileName := fileNameFromURL(targetURL)
	outPath := filepath.Join(outDir, fileName)

	f, err := os.Create(outPath)
	if err != nil {
		return "", fmt.Errorf("create %s: %w", outPath, err)
	}
	defer f.Close()

	if _, err := io.Copy(f, resp.Body); err != nil {
		return "", fmt.Errorf("write %s: %w", outPath, err)
	}

	return outPath, nil
}

func fileNameFromURL(raw string) string {
	parsed, err := url.Parse(raw)
	if err != nil {
		return withPDFSuffix(hashName(raw))
	}

	parts := strings.Split(strings.Trim(parsed.Path, "/"), "/")
	base := "catalog"
	if len(parts) >= 2 {
		base = parts[len(parts)-2]
	} else if len(parts) == 1 && parts[0] != "" {
		base = parts[0]
	}

	base = sanitizeFileName(base)
	if base == "" {
		base = "catalog"
	}

	if parsed.RawQuery == "" {
		return withPDFSuffix(base)
	}
	return withPDFSuffix(base + "-" + hashName(parsed.RawQuery))
}

func hashName(v string) string {
	sum := sha1.Sum([]byte(v))
	return hex.EncodeToString(sum[:])[:10]
}

func sanitizeFileName(v string) string {
	v = strings.ToLower(v)
	v = strings.ReplaceAll(v, " ", "-")

	var b strings.Builder
	for _, r := range v {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == '-' || r == '_' {
			b.WriteRune(r)
		}
	}
	return strings.Trim(b.String(), "-_")
}

func withPDFSuffix(v string) string {
	if strings.HasSuffix(strings.ToLower(v), ".pdf") {
		return v
	}
	return v + ".pdf"
}

func setBrowserHeaders(req *http.Request, referer, accept string) {
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36")
	req.Header.Set("Accept", accept)
	req.Header.Set("Accept-Language", "en-US,en;q=0.9")
	req.Header.Set("Cache-Control", "no-cache")
	req.Header.Set("Pragma", "no-cache")
	if referer != "" {
		req.Header.Set("Referer", referer)
	}
}

func catalogReferer(raw string) string {
	u, err := url.Parse(raw)
	if err != nil {
		return "https://www.spar.si/letak"
	}

	u.Path = strings.TrimSuffix(u.Path, "/getPdf.ashx")
	u.RawQuery = ""
	u.Fragment = ""
	if u.Path == "" {
		return "https://www.spar.si/letak"
	}
	return u.String()
}
