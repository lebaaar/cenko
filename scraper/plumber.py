import pdfplumber
import argparse
from pathlib import Path
import pdfplumber
from pdf2image import convert_from_path
import pytesseract


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("katalogi", help="lokacija do katalogov",
                        type=str)
    args = parser.parse_args()

    path = Path(args.katalogi)

    for f in path.rglob("*.pdf"): 
        
        katalog_txt = { f.parent.name: "" }

        pdf = pdfplumber.open(f)
        for page in pdf.pages:
            katalog_txt[f.parent.name] += page.extract_text(layout=True)
        
        if len(katalog_txt[f.parent.name]) > 50: continue
        print(f)
    
        for i in range(1, len(pdf.pages) + 1):
            images = convert_from_path(f, dpi=300, first_page=i, last_page=i)
            katalog_txt[f.parent.name] = pytesseract.image_to_string(images[0], lang="slv")
        
            



if __name__ == "__main__":
    main()