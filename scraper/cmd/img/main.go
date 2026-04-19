package main

import (
	"scraper/internal/img"
)

func main() {
	img.Init("../../../serviceAccountKey.json")

	//img.NajdiSlike("Mercator")
	//img.NajdiSlike("Spar")
	//img.NajdiSlike("Tuš")
	img.NajdiSlike("Tuš drogerije")
	img.Close()
}
