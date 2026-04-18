package scraper

import (
	"bytes"
	"context"
	"crypto/sha1"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"html"
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
var mercatorPDFLinkPattern = regexp.MustCompile(`(?:https?:)?//(?:www\.)?mercator\.si/assets/[Kk]atalogi/[^\s"'<>\\]+\.pdf(?:\?[^\s"'<>\\]*)?|/assets/[Kk]atalogi/[^\s"'<>\\]+\.pdf(?:\?[^\s"'<>\\]*)?`)
var tusPDFLinkPattern = regexp.MustCompile(`(?:https?:)?//(?:www\.)?tus\.si/app/uploads/catalogues/[^\s"'<>\\]+\.pdf(?:\?[^\s"'<>\\]*)?|/app/uploads/catalogues/[^\s"'<>\\]+\.pdf(?:\?[^\s"'<>\\]*)?`)
var tusCatalogCardPattern = regexp.MustCompile(`(?is)<li[^>]*class="[^"]*list-item[^"]*"[^>]*>.*?<figcaption>.*?<a href="((?:https?:)?//(?:www\.)?tus\.si/app/uploads/catalogues/[^"]+\.pdf|/app/uploads/catalogues/[^"]+\.pdf)"[^>]*class="[^"]*\bpdf\b[^"]*"[^>]*>.*?</figcaption>.*?<h3>\s*<a[^>]*>([^<]+)</a>`)
var lidlFlyerIDPattern = regexp.MustCompile(`data-track-id="([0-9a-fA-F-]{36})"`)

const lidlFlyerAPIURL = "https://endpoints.leaflets.schwarz/v4/flyer?flyer_identifier=%s"

type lidlFlyerResponse struct {
	Flyer struct {
		Name        string `json:"name"`
		PDFURL      string `json:"pdfUrl"`
		HiResPDFURL string `json:"hiResPdfUrl"`
	} `json:"flyer"`
}

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
	setBrowserHeaders(req, pageRequestReferer(targetURL), "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")

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
	return filterCatalogLinks(ExtractSparPDFLinks(body)), nil
}

func ExtractMercatorPDFLinks(pageSource string) []string {
	matches := mercatorPDFLinkPattern.FindAllString(pageSource, -1)
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
			link = "https://www.mercator.si" + link
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

func FetchMercatorPDFLinksFromPage(pageURL string) ([]string, error) {
	body, err := GetPageSource(pageURL)
	if err != nil {
		return nil, err
	}
	return filterCatalogLinks(ExtractMercatorPDFLinks(body)), nil
}

func ExtractTusPDFLinks(pageSource string) []string {
	// Prefer card-aware extraction so we can keep only entries named as catalogs.
	cardMatches := tusCatalogCardPattern.FindAllStringSubmatch(pageSource, -1)
	if len(cardMatches) > 0 {
		seen := make(map[string]struct{}, len(cardMatches))
		links := make([]string, 0, len(cardMatches))

		for _, m := range cardMatches {
			if len(m) < 3 {
				continue
			}
			name := strings.TrimSpace(html.UnescapeString(m[2]))
			link := normalizeTusLink(m[1])
			if link == "" {
				continue
			}
			if !isWantedCatalog(name, link) {
				continue
			}
			if _, ok := seen[link]; ok {
				continue
			}
			seen[link] = struct{}{}
			links = append(links, link)
		}

		sort.Strings(links)
		return links
	}

	// Fallback if card structure changes.
	matches := tusPDFLinkPattern.FindAllString(pageSource, -1)
	if len(matches) == 0 {
		return nil
	}

	seen := make(map[string]struct{}, len(matches))
	links := make([]string, 0, len(matches))

	for _, m := range matches {
		link := normalizeTusLink(m)
		if _, ok := seen[link]; ok {
			continue
		}
		seen[link] = struct{}{}
		links = append(links, link)
	}

	sort.Strings(links)
	return links
}

func FetchTusPDFLinksFromPage(pageURL string) ([]string, error) {
	body, err := GetPageSource(pageURL)
	if err != nil {
		return nil, err
	}
	return filterCatalogLinks(ExtractTusPDFLinks(body)), nil
}

func ExtractLidlFlyerIDs(pageSource string) []string {
	matches := lidlFlyerIDPattern.FindAllStringSubmatch(pageSource, -1)
	if len(matches) == 0 {
		return nil
	}

	seen := make(map[string]struct{}, len(matches))
	ids := make([]string, 0, len(matches))

	for _, m := range matches {
		if len(m) < 2 {
			continue
		}
		id := strings.ToLower(strings.TrimSpace(m[1]))
		if id == "" {
			continue
		}
		if _, ok := seen[id]; ok {
			continue
		}
		seen[id] = struct{}{}
		ids = append(ids, id)
	}

	sort.Strings(ids)
	return ids
}

func FetchLidlPDFLinksFromPage(pageURL string) ([]string, error) {
	body, err := GetPageSource(pageURL)
	if err != nil {
		return nil, err
	}

	flyerIDs := ExtractLidlFlyerIDs(body)
	if len(flyerIDs) == 0 {
		return nil, fmt.Errorf("no Lidl flyer IDs found")
	}

	client := newHTTPClient()
	seen := make(map[string]struct{}, len(flyerIDs))
	links := make([]string, 0, len(flyerIDs))

	for _, id := range flyerIDs {
		name, link, err := fetchLidlPDFURL(client, id, pageURL)
		if err != nil {
			return nil, err
		}
		if !isWantedCatalog(name, link) {
			continue
		}
		if link == "" {
			continue
		}
		if _, ok := seen[link]; ok {
			continue
		}
		seen[link] = struct{}{}
		links = append(links, link)
	}

	sort.Strings(links)
	return links, nil
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
		savedPath, _, err := downloadFile(client, link, outDir)
		if err != nil {
			return saved, err
		}
		saved = append(saved, savedPath)
	}

	return saved, nil
}

func DownloadMercatorCatalogPDFs(pageURL, outputRoot, storeName string) ([]string, error) {
	links, err := FetchMercatorPDFLinksFromPage(pageURL)
	if err != nil {
		return nil, err
	}
	if len(links) == 0 {
		return nil, fmt.Errorf("no Mercator PDF links found")
	}

	outDir := filepath.Join(outputRoot, storeName)
	if err := os.MkdirAll(outDir, 0o755); err != nil {
		return nil, fmt.Errorf("create output directory: %w", err)
	}

	client := newHTTPClient()
	saved := make([]string, 0, len(links))

	for _, link := range links {
		savedPath, _, err := downloadFile(client, link, outDir)
		if err != nil {
			return saved, err
		}
		saved = append(saved, savedPath)
	}

	return saved, nil
}

func DownloadTusCatalogPDFs(pageURL, outputRoot, storeName string) ([]string, error) {
	links, err := FetchTusPDFLinksFromPage(pageURL)
	if err != nil {
		return nil, err
	}
	if len(links) == 0 {
		return nil, fmt.Errorf("no Tuš PDF links found")
	}

	outDir := filepath.Join(outputRoot, storeName)
	if err := os.MkdirAll(outDir, 0o755); err != nil {
		return nil, fmt.Errorf("create output directory: %w", err)
	}

	client := newHTTPClient()
	saved := make([]string, 0, len(links))

	for _, link := range links {
		savedPath, _, err := downloadFile(client, link, outDir)
		if err != nil {
			return saved, err
		}
		saved = append(saved, savedPath)
	}

	return saved, nil
}

func DownloadLidlCatalogPDFs(pageURL, outputRoot, storeName string) ([]string, error) {
	links, err := FetchLidlPDFLinksFromPage(pageURL)
	if err != nil {
		return nil, err
	}
	if len(links) == 0 {
		return nil, fmt.Errorf("no Lidl PDF links found")
	}

	outDir := filepath.Join(outputRoot, storeName)
	if err := os.MkdirAll(outDir, 0o755); err != nil {
		return nil, fmt.Errorf("create output directory: %w", err)
	}

	client := newHTTPClient()
	saved := make([]string, 0, len(links))

	for _, link := range links {
		savedPath, _, err := downloadFile(client, link, outDir)
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

func downloadFile(client *http.Client, targetURL, outDir string) (string, bool, error) {
	req, err := http.NewRequest(http.MethodGet, targetURL, nil)
	if err != nil {
		return "", false, fmt.Errorf("create download request for %s: %w", targetURL, err)
	}
	setBrowserHeaders(req, catalogReferer(targetURL), "application/pdf,application/octet-stream;q=0.9,*/*;q=0.8")

	resp, err := client.Do(req)
	if err != nil {
		return "", false, fmt.Errorf("download %s: %w", targetURL, err)
	}

	if resp.StatusCode == http.StatusForbidden {
		resp.Body.Close()

		retryReq, reqErr := http.NewRequest(http.MethodGet, targetURL, nil)
		if reqErr != nil {
			return "", false, fmt.Errorf("create retry request for %s: %w", targetURL, reqErr)
		}
		setBrowserHeaders(retryReq, "https://www.spar.si/letak", "application/pdf,application/octet-stream;q=0.9,*/*;q=0.8")

		resp, err = client.Do(retryReq)
		if err != nil {
			return "", false, fmt.Errorf("retry download %s: %w", targetURL, err)
		}
	}
	defer resp.Body.Close()

	if resp.StatusCode < http.StatusOK || resp.StatusCode >= http.StatusMultipleChoices {
		return "", false, fmt.Errorf("download %s: unexpected status code: %d", targetURL, resp.StatusCode)
	}

	fileName := fileNameFromURL(targetURL)
	outPath := filepath.Join(outDir, fileName)
	f, err := os.CreateTemp(outDir, fileName+".*.tmp")
	if err != nil {
		return "", false, fmt.Errorf("create temp file for %s: %w", outPath, err)
	}
	tempPath := f.Name()

	if _, err := io.Copy(f, resp.Body); err != nil {
		f.Close()
		_ = os.Remove(tempPath)
		return "", false, fmt.Errorf("write %s: %w", tempPath, err)
	}
	if err := f.Close(); err != nil {
		_ = os.Remove(tempPath)
		return "", false, fmt.Errorf("close %s: %w", tempPath, err)
	}

	same, err := filesEqual(outPath, tempPath)
	if err != nil {
		_ = os.Remove(tempPath)
		return "", false, err
	}
	if same {
		_ = os.Remove(tempPath)
		return outPath, true, nil
	}

	if err := os.Rename(tempPath, outPath); err != nil {
		_ = os.Remove(tempPath)
		return "", false, fmt.Errorf("replace %s: %w", outPath, err)
	}

	return outPath, false, nil
}

func fileNameFromURL(raw string) string {
	parsed, err := url.Parse(raw)
	if err != nil {
		return withPDFSuffix(hashName(raw))
	}

	pathValue := strings.Trim(parsed.Path, "/")
	parts := strings.Split(pathValue, "/")
	base := "catalog"
	if len(parts) > 0 {
		last := parts[len(parts)-1]
		if strings.HasSuffix(strings.ToLower(last), ".pdf") {
			base = strings.TrimSuffix(last, filepath.Ext(last))
		} else if len(parts) >= 2 {
			base = parts[len(parts)-2]
		} else if last != "" {
			base = last
		}
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

func pageReferer(raw string) string {
	u, err := url.Parse(raw)
	if err != nil || u.Scheme == "" || u.Host == "" {
		return ""
	}
	return u.Scheme + "://" + u.Host + "/"
}

func pageRequestReferer(raw string) string {
	u, err := url.Parse(raw)
	if err != nil {
		return ""
	}
	host := strings.ToLower(u.Host)
	if strings.Contains(host, "spar.si") {
		return "https://www.spar.si/letak"
	}
	return pageReferer(raw)
}

func filesEqual(pathA, pathB string) (bool, error) {
	infoA, err := os.Stat(pathA)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return false, nil
		}
		return false, fmt.Errorf("stat %s: %w", pathA, err)
	}

	infoB, err := os.Stat(pathB)
	if err != nil {
		return false, fmt.Errorf("stat %s: %w", pathB, err)
	}

	if infoA.Size() != infoB.Size() {
		return false, nil
	}

	a, err := os.ReadFile(pathA)
	if err != nil {
		return false, fmt.Errorf("read %s: %w", pathA, err)
	}
	b, err := os.ReadFile(pathB)
	if err != nil {
		return false, fmt.Errorf("read %s: %w", pathB, err)
	}

	return bytes.Equal(a, b), nil
}

func fetchLidlPDFURL(client *http.Client, flyerID, pageURL string) (string, string, error) {
	apiURL := fmt.Sprintf(lidlFlyerAPIURL, url.QueryEscape(flyerID))
	req, err := http.NewRequest(http.MethodGet, apiURL, nil)
	if err != nil {
		return "", "", fmt.Errorf("create Lidl flyer request for %s: %w", flyerID, err)
	}
	setBrowserHeaders(req, pageRequestReferer(pageURL), "application/json,text/plain,*/*")

	resp, err := client.Do(req)
	if err != nil {
		return "", "", fmt.Errorf("fetch Lidl flyer %s: %w", flyerID, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < http.StatusOK || resp.StatusCode >= http.StatusMultipleChoices {
		return "", "", fmt.Errorf("fetch Lidl flyer %s: unexpected status code: %d", flyerID, resp.StatusCode)
	}

	var payload lidlFlyerResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return "", "", fmt.Errorf("decode Lidl flyer %s: %w", flyerID, err)
	}

	link := strings.TrimSpace(payload.Flyer.HiResPDFURL)
	if link == "" {
		link = strings.TrimSpace(payload.Flyer.PDFURL)
	}

	return strings.TrimSpace(payload.Flyer.Name), link, nil
}

func normalizeTusLink(v string) string {
	link := strings.ReplaceAll(v, `\/`, `/`)
	if strings.HasPrefix(link, "//") {
		link = "https:" + link
	} else if strings.HasPrefix(link, "/") {
		link = "https://www.tus.si" + link
	}

	return strings.TrimRight(link, ".,)")
}

func isWantedCatalog(name, link string) bool {
	text := strings.ToLower(name + " " + link)
	excludedKeywords := []string{
		"trajnost",
		"vodnik",
		"po-poti-dobrih-vin",
		"po poti dobrih vin",
		"zgodbe-iz-mojega-vrta",
		"zgodbe iz mojega vrta",
		"vinski-katalog",
		"vinski katalog",
		"vrtni-katalog",
		"vrtni katalog",
		"kuharija",
	}

	for _, keyword := range excludedKeywords {
		if strings.Contains(text, keyword) {
			return false
		}
	}

	return true
}

func filterCatalogLinks(links []string) []string {
	if len(links) == 0 {
		return nil
	}

	filtered := make([]string, 0, len(links))
	for _, link := range links {
		if !isWantedCatalog("", link) {
			continue
		}
		filtered = append(filtered, link)
	}

	return filtered
}
