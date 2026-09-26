import sys
from medical_scraper import scan_medical_jobs

def test():
    print("Scanning 4 specs...")
    jobs_4 = scan_medical_jobs(selected_specialties=["neuro", "ortho", "anaesth", "interne"], selected_countries=["DE"], selected_hospital_types=["uni", "maximal", "grund", "fach"])
    print(f"4 specs -> {len(jobs_4)} jobs")
    
    print("Scanning 38 specs...")
    from config import SPECIALTIES
    jobs_all = scan_medical_jobs(selected_specialties=list(SPECIALTIES.keys())[:38], selected_countries=["DE"], selected_hospital_types=["uni", "maximal", "grund", "fach"])
    print(f"38 specs -> {len(jobs_all)} jobs")

if __name__ == "__main__":
    test()
