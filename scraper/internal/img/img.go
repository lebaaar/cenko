package img

import (
	"context"
	"fmt"
	"log"
	"net/url"
	"strings"
	"time"

	"cloud.google.com/go/firestore"
	"github.com/playwright-community/playwright-go"
	"google.golang.org/api/iterator"
	"google.golang.org/api/option"

	firebase "firebase.google.com/go/v4"
)

type Product struct {
	Brand         string    `firestore:"brand"`
	DiscountPct   int64     `firestore:"discount_pct"`
	Image         string    `firestore:"image"`
	OriginalPrice int64     `firestore:"original_price"`
	ProductName   string    `firestore:"product_name"`
	SalePrice     int64     `firestore:"sale_price"`
	ScrapedAt     time.Time `firestore:"scraped_at"`
	StoreName     string    `firestore:"store_name"`
	ValidFrom     time.Time `firestore:"valid_from"`
	ValidUntil    time.Time `firestore:"valid_until"`
}

const (
	MERCATOR_URL = "https://mercatoronline.si/brskaj#search=%s"
	SPAR_URL     = "https://online.spar.si/search?name=%s"
	TUS_URL      = "https://www.tus.si/?post_type=product&woof_text=%s"
	TUSD_URL     = "https://www.tusdrogerija.si/iskanje?text=%s"
	HOFER_URL    = "https://www.hofer.si/rezultat?q=%s"
)

var (
	Pw         *playwright.Playwright
	Browser    playwright.Browser
	FireClient *firestore.Client
)

func Init(key string) {

	pw, err := playwright.Run()

	if err != nil {
		log.Fatalf("could not start playwright: %v", err)
	}
	browser, err := pw.Chromium.Launch(playwright.BrowserTypeLaunchOptions{
		Headless: playwright.Bool(true),
		Args: []string{
			"--ignore-certificate-errors",
		},
	})

	if err != nil {
		log.Fatalf("could not launch browser: %v", err)
	}

	Pw = pw
	Browser = browser

	ctx := context.Background()
	sa := option.WithCredentialsFile(key)
	app, err := firebase.NewApp(ctx, nil, sa)
	if err != nil {
		log.Fatalln(err)
	}

	client, err := app.Firestore(ctx)
	if err != nil {
		log.Fatalln(err)
	}
	FireClient = client

}

func NajdiSlike(trgovina string) {

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Minute)
	defer cancel()

	iter := FireClient.Collection("catalog_products").
		Where("store_name", "==", trgovina).
		Where("image", "==", "").
		Documents(ctx)

	log.Printf("Iščem za trgovino %s...\n", trgovina)
	uspesnih := 0
	useh := 0

	for {
		doc, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			log.Print(err)
		}

		var p Product
		if err := doc.DataTo(&p); err != nil {
			log.Print(err)
		}

		parts := strings.Fields(p.ProductName)
		var result string
		if trgovina != "Hofer" && len(parts) >= 2 {
			result = strings.Join(parts[:2], " ")
			if len(parts[1]) < 3 && len(parts) > 2 {
				result = strings.Join(parts[:3], " ")
			}

		} else {
			result = p.ProductName
		}

		link := isci(result, trgovina)
		if link == "" || link == "https://mercatoronline.si/img/no-image-small.jpg" {
			useh++
			continue
		}

		log.Printf("Najdena slika %s za %s\n", link, p.ProductName)
		uspesnih++
		useh++
		_, err = doc.Ref.Update(ctx, []firestore.Update{
			{
				Path:  "image",
				Value: link,
			},
		})

		if err != nil {
			log.Print(err)
		}

		time.Sleep(time.Second * 2)
	}
	log.Printf("Zaključeno iskanje: %d/%d\n", uspesnih, useh)
}

func isci(name string, trgovina string) string {

	url := trgovinaUrl(trgovina, name)

	log.Println(url)

	page, err := Browser.NewPage()
	page.SetDefaultTimeout(15000)

	if err != nil {
		log.Printf("could not create page: %v", err)
		return ""
	}

	defer page.Close()

	if _, err = page.Goto(url); err != nil {
		log.Printf("could not goto: %v", err)
		return ""
	}

	loc := ""
	switch trgovina {
	case "Mercator":
		loc = "a.product-image > img"
	case "Spar":
		loc = ".card-product-vertical .ant-image-img"
	case "Tuš":
		loc = "img.thumbnail"
	case "Tuš drogerije":
		loc = ".imageContainer .mainImage"
	case "Hofer":
		loc = ".product-tile__picture > img"
	}

	entry := page.Locator(loc).First()
	atr, err := entry.GetAttribute("src")

	if err != nil {
		log.Printf("could not get entries: %v", err)
		return ""
	}

	return atr

}

func trgovinaUrl(trgovina string, artikel string) string {
	uri := ""
	switch trgovina {
	case "Mercator":
		uri = MERCATOR_URL
	case "Spar":
		uri = SPAR_URL
	case "Tuš":
		uri = TUS_URL
	case "Hofer":
		uri = HOFER_URL
	case "Tuš drogerije":
		uri = TUSD_URL
	}
	return fmt.Sprintf(uri, url.QueryEscape(artikel))
}

func Close() {

	if err := FireClient.Close(); err != nil {
		log.Fatalf("could not close fire client: %v", err)
	}

	if err := Browser.Close(); err != nil {
		log.Fatalf("could not close browser: %v", err)
	}
	if err := Pw.Stop(); err != nil {
		log.Fatalf("could not stop Playwright: %v", err)
	}

}
