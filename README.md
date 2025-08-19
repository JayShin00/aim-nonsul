# aim_nonsul
College Scholastic Ability Test (CSAT) and Essay D-Day App

## Branch Strategy
Production branch- main

Latest update branch- feat/#2-first-update

## Technology Stack
Framework: Flutter 3.29.2, Dart 3.7.2, Material Design

Backend(BaaS): Firebase (Core, Cloud Firestore)

Home widget: Flutter home_widget + iOS WidgetKit(SwiftUI), Android AppWidget(Kotlin)

## Firebase Settings
- Project root path > Add New service account key file > Add the key value to the SERVICE_ACCOUNT_KEY_PATH variable in the upload_exam_schedule.py
- Add the android/app/google-services.json file
- Add the ios/Runner/GoogleService-Info.plist file

## How to update data
1. Modify the data in the assets/exam_schedule.csv file
2. Execute the command after modification - python3 upload_exam_schedule.py

## Caution
- Make sure the service account key path and the CSV file path match

## Contact us
- Technical manager: kyle@aimscore.ai
- Frontend developer: jay@aimscore.ai
