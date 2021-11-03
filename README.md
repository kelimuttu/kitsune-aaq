# kitsune-aaq
List of questions from all locales from Kitsune AAQ for Firefox Desktop, Firefox for Android, and Firefox for iOS

# How to set up

## Set up the database
```bash
. ./setupDatabase
```

## Get all questions
```bash
./get-desktop-questions.rb YYYY MM DD
./get-android-questions.rb YYYY MM DD
./get-ios-questions.rb YYYY MM DD
./get-focus-questions.rb YYYY MM DD
```

## Print data to CSV
```bash
./print-desktop.rb YYYY MM DD YYYY MM DD filename-desktop.csv
./print-android.rb YYYY MM DD YYYY MM DD filename-android.csv
./print-ios.rb YYYY MM DD YYYY MM DD filename-ios.csv
./print-focus.rb YYYY MM DD YYYY MM DD filename-focus.csv
```