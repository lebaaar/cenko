package main

import (
	"fmt"
	"os"
	"scraper/internal/scraper"
)

func main() {
	const pageURL = "https://www.spar.si/letak?ecid=SEM_spar_splosno_spar_e-katalogi"

	storeName := "spar"
	if len(os.Args) > 1 && os.Args[1] != "" {
		storeName = os.Args[1]
	}

	savedPaths, err := scraper.DownloadCatalogPDFs(pageURL, "katalogi", storeName)
	if err != nil {
		fmt.Println(err)
		return
	}

	fmt.Printf("Downloaded %d PDF files to katalogi/%s\n", len(savedPaths), storeName)
	for _, p := range savedPaths {
		fmt.Println(p)
	}
}
