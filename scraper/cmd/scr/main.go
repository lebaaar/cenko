package main

import (
	"fmt"
	"os"
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

	if len(os.Args) == 1 || os.Args[1] == "all" {
		var (
			wg       sync.WaitGroup
			outputMu sync.Mutex
		)

		type storeJob struct {
			key        string
			name       string
			pageURL    string
			downloader func(pageURL, outputRoot, storeName string) ([]string, error)
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
				runStore(j.key, j.name, j.pageURL, outputRoot, j.downloader, &outputMu)
			}(job)
		}

		wg.Wait()
		return
	}

	storeKey := os.Args[1]
	storeName := storeKey
	if len(os.Args) > 2 && os.Args[2] != "" {
		storeName = os.Args[2]
	}

	switch storeKey {
	case "spar":
		runStore("spar", storeName, sparPageURL, outputRoot, scraper.DownloadCatalogPDFs, nil)
	case "mercator":
		runStore("mercator", storeName, mercatorPageURL, outputRoot, scraper.DownloadMercatorCatalogPDFs, nil)
	case "lidl":
		runStore("lidl", storeName, lidlPageURL, outputRoot, scraper.DownloadLidlCatalogPDFs, nil)
	case "tus":
		runStore("tus", storeName, tusPageURL, outputRoot, scraper.DownloadTusCatalogPDFs, nil)
	default:
		fmt.Println("usage: go run ./cmd/scr [all|spar|mercator|lidl|tus] [storeName]")
	}
}

func runStore(
	storeKey string,
	storeName string,
	pageURL string,
	outputRoot string,
	downloader func(pageURL, outputRoot, storeName string) ([]string, error),
	outputMu *sync.Mutex,
) {
	savedPaths, err := downloader(pageURL, outputRoot, storeName)

	if outputMu != nil {
		outputMu.Lock()
		defer outputMu.Unlock()
	}

	if err != nil {
		fmt.Printf("%s error: %v\n", storeKey, err)
		return
	}

	fmt.Printf("Downloaded %d PDF files to katalogi/%s (%s)\n", len(savedPaths), storeName, storeKey)
	for _, p := range savedPaths {
		fmt.Println(p)
	}
}
