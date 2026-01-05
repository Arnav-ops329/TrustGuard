import pandas as pd
import joblib
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression

data = {
    "text": [
        "Government launches new education policy",
        "You won lottery claim now",
        "NASA discovers water on moon",
        "Bank account blocked click link",
        "WHO releases new health guidelines",
        "Urgent KYC update required"
    ],
    "label": [1, 0, 1, 0, 1, 0]  # 1 = Real, 0 = Fake
}

df = pd.DataFrame(data)

vectorizer = TfidfVectorizer(stop_words='english')
X = vectorizer.fit_transform(df["text"])
y = df["label"]

model = LogisticRegression()
model.fit(X, y)

joblib.dump(model, "fake_news_model.pkl")
joblib.dump(vectorizer, "vectorizer.pkl")

print("Model trained successfully")
