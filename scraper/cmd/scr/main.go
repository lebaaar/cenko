package main

import (
	"fmt"
	"os"
	"scraper/internal/scraper"
)

func main() {
	const (
		sparPageURL     = "https://www.spar.si/letak?ecid=SEM_spar_splosno_spar_e-katalogi"
		mercatorPageURL = "https://www.mercator.si/katalogi/"
		outputRoot      = "katalogi"
	)

	if len(os.Args) == 1 || os.Args[1] == "all" {
		runStore("spar", "spar", sparPageURL, outputRoot, scraper.DownloadCatalogPDFs)
		runStore("mercator", "mercator", mercatorPageURL, outputRoot, scraper.DownloadMercatorCatalogPDFs)
		return
	}

	storeKey := os.Args[1]
	storeName := storeKey
	if len(os.Args) > 2 && os.Args[2] != "" {
		storeName = os.Args[2]
	}

	switch storeKey {
	case "spar":
		runStore("spar", storeName, sparPageURL, outputRoot, scraper.DownloadCatalogPDFs)
	case "mercator":
		runStore("mercator", storeName, mercatorPageURL, outputRoot, scraper.DownloadMercatorCatalogPDFs)
	default:
		fmt.Println("usage: go run ./cmd/scr [all|spar|mercator] [storeName]")
	}
}

func runStore(
	storeKey string,
	storeName string,
	pageURL string,
	outputRoot string,
	downloader func(pageURL, outputRoot, storeName string) ([]string, error),
) {
	savedPaths, err := downloader(pageURL, outputRoot, storeName)
	if err != nil {
		fmt.Printf("%s error: %v\n", storeKey, err)
		return
	}

	fmt.Printf("Downloaded %d PDF files to katalogi/%s (%s)\n", len(savedPaths), storeName, storeKey)
	for _, p := range savedPaths {
		fmt.Println(p)
	}
}
