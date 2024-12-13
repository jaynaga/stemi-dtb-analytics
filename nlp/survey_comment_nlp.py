"""
survey_comment_nlp.py

Text preprocessing pipeline for free-text staff survey comments collected
after the OpenEMR clinical decision support rollout. Tokenizes, removes
stopwords, and lemmatizes comments, then produces a word-frequency table
used to build a word cloud visualization in the Tableau dashboard.

Usage:
    python survey_comment_nlp.py --input ../data/Updated_STEMI_Survey_Responses.csv \
                                  --output wordcloud_data.csv
"""

import argparse
import re

import nltk
import pandas as pd
from nltk.corpus import stopwords
from nltk.stem import WordNetLemmatizer


def ensure_nltk_data() -> None:
    for resource in ("stopwords", "wordnet", "omw-1.4"):
        try:
            nltk.data.find(f"corpora/{resource}")
        except LookupError:
            nltk.download(resource)


def preprocess_text(text: str, stop_words: set, lemmatizer: WordNetLemmatizer) -> str:
    text = text.lower()
    text = re.sub(r"[^\w\s]", "", text)  # remove punctuation
    tokens = text.split()
    tokens = [w for w in tokens if w not in stop_words]
    tokens = [lemmatizer.lemmatize(w) for w in tokens]
    return " ".join(tokens)


def main(input_path: str, output_path: str) -> None:
    ensure_nltk_data()
    stop_words = set(stopwords.words("english"))
    lemmatizer = WordNetLemmatizer()

    df = pd.read_csv(input_path)

    if "Comments" in df.columns:
        df["processed_comments"] = (
            df["Comments"].astype(str).apply(lambda t: preprocess_text(t, stop_words, lemmatizer))
        )

    df = df.dropna(subset=["Comments"])

    # Word-frequency table for the Tableau word cloud
    word_series = df["processed_comments"].str.split().explode()
    word_counts = word_series.value_counts().reset_index()
    word_counts.columns = ["Word", "Frequency"]
    word_counts.to_csv(output_path, index=False)

    print(f"Processed {len(df)} survey responses.")
    print(f"Wrote word-frequency table to {output_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", default="../data/Updated_STEMI_Survey_Responses.csv")
    parser.add_argument("--output", default="wordcloud_data.csv")
    args = parser.parse_args()
    main(args.input, args.output)
