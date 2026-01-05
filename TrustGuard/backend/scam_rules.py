SCAM_KEYWORDS = [
    "urgent", "click", "verify", "account blocked",
    "lottery", "won", "free", "prize", "otp", "kyc"
]

def detect_scam(text):
    text = text.lower()
    matches = [word for word in SCAM_KEYWORDS if word in text]
    return {
        "is_scam": len(matches) > 0,
        "matched_words": matches
    }
