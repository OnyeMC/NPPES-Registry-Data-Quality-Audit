# NPPES-Registry-Data-Quality-Audit

## Introduction
Ensuring that provider information is up to date is important for many healthcare operations to function smoothly. Ensuring this information is accurate is necessary to avoid expensive and time-consuming errors, such as denied claims, fines for non-compliance, and increased customer escalations. One way to ensure that this information is correct is through cross-referencing a registry, such as the NPPES NPI registry. However, a large amount of information in this directory appears to be outdated or incorrect. For this project, I will be evaluating the NPPES NPI registry by these four standards to assess its validity as a source for accurate provider information:
* **Completeness:** all required information is included
* **Accuracy:** information is correct for the provider
* **Validity:** information makes sense
* **Timeliness:** information is up to date

## Data
### Primary Dataset
* [Monthly NPPES Downloadable File V.2 (Jun 8, 2026 release)](https://download.cms.gov/nppes/NPI_Files.html)
  * Python was used to create a smaller random sample size of 5000 providers, as well as to standardize the addresses/taxonomy codes
### External Validation Sources
* [Doctors and Clinicians National Downloadable File (Jun 11, 2026 release)](https://data.cms.gov/provider-data/dataset/mj5m-pzi6)
* [Medicare Provider and Supplier Taxonomy Crosswalk (Nov 2025)](https://data.cms.gov/provider-characteristics/medicare-provider-supplier-enrollment/medicare-provider-and-supplier-taxonomy-crosswalk/data)
  * Additional taxonomy codes not included in the original file were also added to the list or manually edited into the final NPPES sample as needed
* [List of Professional Credentials Abbreviations](https://oley.org/page/Abbreviation-Credentials)
  * Added missing uncommon credentials that are valid (OD, DPM, DDS, DMD, AUD, NP, PT, OT, PSYD, WHNP, LMHC, LMFT)
  * Removed non-medical credentials (BA, BS, MA, MS, MSc)

## Creating Samples & Cleaning Datasets
Two Python files were used to obtain a smaller subset of the data, as well as to clean the data.
* **PDQA_creating samples:** using the first section of the NPPES Monthly Downloadable file, this creates a small subsection of 5,000 randomly selected providers that are also included in the CMS data file; a new CMS data file containing only the providers in this sample was also created
  * Some preliminary cleaning of the data, such as standardizing addresses and converting taxonomy codes into specialties, was also done at this step
* **PDQA_cleaning_samples:** the following additional adjustments were made in this file
  * Columns with no values in any row were removed
  * Numbers after the first 5 numbers in the zip code were removed
  * Combined 1st and 2nd line addresses into one full address column for both datasets
  * Removed punctuation and white spaces in individual names
  * Removed duplicate entries from the CMS table (duplicates were determined by matching NPI and address; thefuzz with a threshold of 85 was used to determine duplicates with similar, but not exactly matching addresses)
  * Removed unnecessary columns
  * Removed spaces/punctuation from provider names
  * Standardized NPPES & CMS primary specialty names so that they matched more (capitalized all specialties, removed unnecessary phrases & punctuation, & replaced values for common taxonomies so that both columns matched)

## Analyzing Data
The clean CMS/NPPES datasets, as well as the other external validation sources, were then imported into PostgreSQL for analysis using the following criteria:

### Timeliness
* Percentages of how long ago the NPPES was updated (by years)
  * Another query to match each year group with the provider was also made
### Completeness
* Number of records that are missing important information (first/middle/last name, credential, gender, address, primary specialty)
### Accuracy
* Gender mismatches
* Credential mismatches
  * A similarity threshold of 0.30 was used to catch only those with almost no matching pairs; an extra rule to remove matches for DC = CH (chiropractor) was also added
* First, last, and middle name mismatches
  * Only exact matches were taken since inaccuracies in these fields are essential for administrative tasks, but not as easy to verify as addresses
  * Middle name matches were done by either the full name or only the initial if the full name was not available in either the NPPES or CMS tables
* Primary specialty mismatches
  * A similarity threshold of 0.3 was used to separate specialties that were mismatched due to being different vs through variations in how they were typed;
* Address mismatches
  * A similarity threshold of 0.75 was used to find mismatches, even if there were slight variations/typos
### Validity
* Invalid credentials
* Invalid prefix/suffix
* Invalid addresses (organization name as first line, PO box, etc.)

## Discussion
[Click here to see the interactive dashboard](https://app.powerbi.com/view?r=eyJrIjoiN2QwOTZkMTktMTg5ZC00YmUzLTljMjgtZWMzZmVjMDExNjg3IiwidCI6ImQ1N2QzMmNjLWMxMjEtNDg4Zi1iMDdiLWRmZTcwNTY4MGM3MSIsImMiOjN9) 

### Timeliness
Only 36.32% of providers in the sample were updated within the last 5 years. The remaining records were last updated from 5 to over 15 years ago. Providers updated within the last 5 years had a significantly higher percentage of complete and accurate provider records (92.70% vs 85.22% for completeness, and 73.90% vs 56.10% for accuracy). It has a slightly lower number of valid providers, but the difference between these is negligible (99.08% vs 99.12%). The trends mentioned below across completeness, accuracy, and validity also generally hold for all groups.
### Completeness
Only the primary specialty, credential, or middle name was missing in all sampled records. Of all categories, the middle name was the most frequently missing, with just over 20% of records lacking it. The primary specialty and credentials were also missing in several records. While this information was not missing as frequently as the middle name, these are still important to note, as accuracy in these fields is essential for confirming provider information. In total, 22% of records in the sample had missing information.
### Accuracy
While all categories had at least some providers with inaccurate information, the address, primary specialty, and credentials were the biggest sources of inaccuracy, especially when it comes to the address. Based on the average similarity scores of all address categories (street address, city, state, and zip code), 32% of records in the sample had mismatched information. The second largest source of inaccurate information was the primary specialty, where 21% of records were inaccurate. Only 7.9% of records had mismatched credential information. 
### Validity
44 invalid addresses were found. The most common reason why these addresses were invalid was that the organization name was included in the address, with 63% of address errors being due to this issue. Other errors were due to a missing street number, including the PO Box, and other inconsistencies that made the address undecipherable (ex: includes multiple addresses/street numbers).
27 invalid credentials were found. However, only 5 of these were due to actual mismatching credential information. The vast majority (81%) of all invalid credentials found were due to minor syntax errors, such as using the full term instead of the abbreviation or typos (ex: M D instead of MD). In fact, 59% of all errors were due to typos.
No invalid prefixes or suffixes were found. Because of this, these were not included in the final report.
### Overall Metrics
The final average quality score for the whole dataset was 60.83%. This was based on an average of all scores using the following weightings:
* Timeliness (Up-to-Date): 0.2
* Completeness: 0.2
* Accuracy: 0.3
* Validity: 0.3

These weightings were based on each category’s importance in a healthcare setting. The NPPES NPI registry performed very well in terms of validity, with almost 98.58% of included providers having no invalid information. It also performed relatively well on completeness, with 77.92% of providers having no missing information. However, it did poorly when it came to accuracy and up-to-date information. Only 33.82% of providers were completely accurate, and only 27.64% were completely up-to-date. The large number of inaccurate addresses and primary specialties are the main contributors to why the scoring for accuracy is so low. Timeliness was rated low due to the distribution of missing, inaccurate, or invalid information across all providers in the dataset. These issues were widespread across all providers, rather than being localized to a select few.

### Limitations
Due to the amount of variability that can be found in addresses, credentials, and primary specialties due to differences in how they can be written (St vs Streets, WHNP vs NP, Radiology vs Interventional Radiology, etc.), similarity scores were used when comparing these items. While thresholds were adjusted and additional edits were made to the data in Power BI to exclude as many matches as possible, there is still a chance that some invalid or inaccurate information was left out or included. The CMS table may also have included some inaccurate information. While any inaccurate matches that were found were removed, it is still possible some incorrect matches were left in the data. Lastly, addresses were only tested on whether they had the correct syntax, rather than if the location exists. It may be possible that some invalid addresses were excluded from the invalid addresses found, if they were formatted correctly. 

## Conclusion
While the NPPES NPI registry is still a good source for finding a large amount of valid provider information, the information is very prone to including inaccurate or out-of-date information. While some errors can be quickly and easily deciphered or verified, it is best to use caution when using it as a source for provider information in categories such as the provider’s primary specialty or address, since they have a significantly higher chance of being incorrect. Checking last update dates, as well as cross-referencing other resources, such as the health organization’s website or the USPS Zip Code Lookup website, should be done to determine that provider information is input as accurately as possible to ensure minimal disruptions or delays to healthcare operations. Initiatives that educate providers on the importance of having accurate information and encourage them to update their file when needed could also help to improve the accuracy of the database.
