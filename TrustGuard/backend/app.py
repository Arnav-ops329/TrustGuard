from fastapi import FastAPI
import joblib
from scam_rules import detect_scam

app = FastAPI()

model = joblib.load("fake_news_model.pkl")
vectorizer = joblib.load("vectorizer.pkl")

@app.post("/check-news")
def check_news(data: dict):
    text = data["text"].lower()

    # -------- MEDICAL FAKE NEWS RULES --------
    medical_red_flags = [
        "cures cancer",
        "cure cancer",
        "miracle cure",
        "guaranteed cure",
        "100% cure",
        "no side effects",
        "doctors hide",
        "ancient remedy"
    ]

    for phrase in medical_red_flags:
        if phrase in text:
            return {
                "news": "Fake",
                "reason": "Unverified medical cure claim"
            }

    # -------- FALLBACK TO ML MODEL --------
    prediction = ml_predict(text)   # your existing model function

    return {
        "news": prediction,
        "reason": "ML-based linguistic analysis"
    }


@app.post("/check-scam")
def check_scam(data: dict):
    return detect_scam(data["text"])

