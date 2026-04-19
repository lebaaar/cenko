package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"scraper/internal/scraper"
	"sync"
)

func main() {
	const (
		sparPageURL     = "https://www.spar.si/letak?ecid=SEM_spar_splosno_spar_e-katalogi"
		mercatorPageURL = "https://www.mercator.si/katalogi/"
		lidlPageURL     = "https://www.lidl.si/c/spletni-katalog/s10019133"
		tusPageURL      = "https://www.tus.si/aktualno/katalogi-in-revije/"
		outputRoot      = "katalogi"
	)
	indexPath := filepath.Join(outputRoot, "catalog-names.json")
	index, err := scraper.LoadCatalogNameIndex(indexPath)
	if err != nil {
		fmt.Printf("index error: %v\n", err)
		return
	}

	if len(os.Args) == 1 || os.Args[1] == "all" {
		var (
			wg       sync.WaitGroup
			outputMu sync.Mutex
		)

		type storeJob struct {
			key        string
			name       string
			pageURL    string
			downloader func(pageURL, outputRoot, storeName string, index *scraper.CatalogNameIndex) (scraper.DownloadResult, error)
		}

		jobs := []storeJob{
			{key: "spar", name: "spar", pageURL: sparPageURL, downloader: scraper.DownloadCatalogPDFs},
			{key: "mercator", name: "mercator", pageURL: mercatorPageURL, downloader: scraper.DownloadMercatorCatalogPDFs},
			{key: "lidl", name: "lidl", pageURL: lidlPageURL, downloader: scraper.DownloadLidlCatalogPDFs},
			{key: "tus", name: "tus", pageURL: tusPageURL, downloader: scraper.DownloadTusCatalogPDFs},
		}

		for _, job := range jobs {
			wg.Add(1)
			go func(j storeJob) {
				defer wg.Done()
				runStore(j.key, j.name, j.pageURL, outputRoot, j.downloader, index, &outputMu)
			}(job)
		}

		wg.Wait()
		if err := index.Save(); err != nil {
			fmt.Printf("index save error: %v\n", err)
		}
		if err := runAfterDownloadScript(); err != nil {
			fmt.Printf("after-download script error: %v\n", err)
		}
		return
	}

	storeKey := os.Args[1]
	storeName := storeKey
	if len(os.Args) > 2 && os.Args[2] != "" {
		storeName = os.Args[2]
	}

	switch storeKey {
	case "spar":
		runStore("spar", storeName, sparPageURL, outputRoot, scraper.DownloadCatalogPDFs, index, nil)
	case "mercator":
		runStore("mercator", storeName, mercatorPageURL, outputRoot, scraper.DownloadMercatorCatalogPDFs, index, nil)
	case "lidl":
		runStore("lidl", storeName, lidlPageURL, outputRoot, scraper.DownloadLidlCatalogPDFs, index, nil)
	case "tus":
		runStore("tus", storeName, tusPageURL, outputRoot, scraper.DownloadTusCatalogPDFs, index, nil)
	default:
		fmt.Println("usage: go run ./cmd/scr [all|spar|mercator|lidl|tus] [storeName]")
		return
	}

	if err := index.Save(); err != nil {
		fmt.Printf("index save error: %v\n", err)
	}
	if err := runAfterDownloadScript(); err != nil {
		fmt.Printf("after-download script error: %v\n", err)
	}
}

func runStore(
	storeKey string,
	storeName string,
	pageURL string,
	outputRoot string,
	downloader func(pageURL, outputRoot, storeName string, index *scraper.CatalogNameIndex) (scraper.DownloadResult, error),
	index *scraper.CatalogNameIndex,
	outputMu *sync.Mutex,
) bool {
	result, err := downloader(pageURL, outputRoot, storeName, index)

	if outputMu != nil {
		outputMu.Lock()
		defer outputMu.Unlock()
	}

	if err != nil {
		fmt.Printf("%s error: %v\n", storeKey, err)
		return false
	}

	fmt.Printf(
		"Downloaded %d PDF files, skipped %d unchanged in katalogi/%s (%s)\n",
		len(result.Downloaded),
		len(result.Skipped),
		storeName,
		storeKey,
	)

	for _, p := range result.Downloaded {
		fmt.Println(p)
	}
	for _, p := range result.Skipped {
		fmt.Printf("%s (skipped)\n", p)
	}
	return true
}

func runAfterDownloadScript() error {
	cwd, err := os.Getwd()
	if err != nil {
		return fmt.Errorf("getwd: %w", err)
	}
	scriptsDir := filepath.Join(cwd, "scripts")

	python := "python3"
	venvCandidates := []string{
		filepath.Join(scriptsDir, ".venv", "bin", "python"),
		filepath.Join(cwd, ".venv", "bin", "python"),
	}
	for _, venvPython := range venvCandidates {
		if _, err := os.Stat(venvPython); err == nil {
			python = venvPython
			break
		}
	}

	fmt.Printf("[scr] running python plumber.py\n")
	cmd := exec.Command(python, filepath.Join(scriptsDir, "plumber.py"), "katalogi")
	cmd.Dir = cwd
	cmd.Env = append(os.Environ(), "PYTHONPATH="+scriptsDir)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}
