# -*- coding: utf-8 -*-
"""
Created on Mon Jun 22 12:46:25 2026

@author: MaryClara Onyedinma

Cleaning Sample Datasets
"""

import pandas as pd
from thefuzz import fuzz

sample_CMS = pd.read_csv("final_CMS_sample.csv", dtype="str")
sample_NPPES = pd.read_csv("final_NPPES_sample.csv", dtype="str",\
                               usecols=[0, *range(2,26)])

#drops columns with only null values
sample_CMS = sample_CMS.dropna(axis=1, how="all")
sample_NPPES = sample_NPPES.dropna(axis=1, how="all")


#rename columns
sample_NPPES = sample_NPPES.rename\
    (columns = {"Provider First Line Business Practice Location Address":"adr_ln_1",\
                "Provider Second Line Business Practice Location Address":"adr_ln_2"})


# keep only first 5 characters for zip codes
sample_NPPES\
    ["Provider Business Practice Location Address Postal Code"]\
        = sample_NPPES\
            ["Provider Business Practice Location Address Postal Code"].str[:5]
sample_CMS["ZIP Code"] = sample_CMS["ZIP Code"].str[:5]


# combine address lines 1/2 to make full street column
cols = ["adr_ln_1", "adr_ln_2"]

sample_NPPES["Full Street Address"] = sample_NPPES[cols].astype(str).apply(\
    lambda row: " ".join([val for val in row if val.strip() and val != "nan" \
                          and val != "None"]), axis=1)
sample_CMS["Full Street Address"] = sample_CMS[cols].astype(str).apply(\
    lambda row: " ".join([val for val in row if val.strip() and val != "nan" \
                          and val != "None"]), axis=1)


# removes duplicate from CMS table
sample_CMS = sample_CMS.drop_duplicates() ## exact matches

## matches w/ the same adrs_id
sample_CMS = sample_CMS.drop_duplicates(subset=["NPI","adrs_id"])

## matches w/ same addresses
EXACT_COL = "NPI"
FUZZY_COL = "adr_ln_1"
duplicates_to_drop = []

for group_name, group in sample_CMS.groupby(EXACT_COL):
    first_occurrence = {}
    
    for i, row in group.iterrows():
        row_text = str(row[FUZZY_COL])
        matched = False
        
        for base_text, base_idx in first_occurrence.items():
            score = fuzz.token_set_ratio(row, base_text)
            if score >= 85:
                duplicates_to_drop.append(i)
                sample_CMS.loc[i, FUZZY_COL] = sample_CMS.loc[base_idx, FUZZY_COL]
                matched = True
                break
        if not matched:
            first_occurrence[row_text] = i

sample_CMS = sample_CMS.drop(index=duplicates_to_drop).reset_index(drop=True)


# remove unneeded columns
sample_NPPES = sample_NPPES.drop(columns=cols)
sample_CMS = sample_CMS.drop(columns=[*cols, "Facility Name"])


#remove spaces & punctuation from names
sample_NPPES["Provider Last Name (Legal Name)"] = sample_NPPES\
    ["Provider Last Name (Legal Name)"].str.replace(r"[^\w]", "", regex=True)
sample_NPPES["Provider First Name"] = sample_NPPES\
    ["Provider First Name"].str.replace(r"[^\w]", "", regex=True)
sample_NPPES["Provider Middle Name"] = sample_NPPES\
    ["Provider Middle Name"].str.replace(r"[^\w]", "", regex=True)
sample_NPPES["Provider Other Last Name"] = sample_NPPES\
    ["Provider Other Last Name"].str.replace(r"[^\w]", "", regex=True)
sample_NPPES["Provider Other First Name"] = sample_NPPES\
    ["Provider Other First Name"].str.replace(r"[^\w]", "", regex=True)
sample_NPPES["Provider Other Middle Name"] = sample_NPPES\
    ["Provider Other Middle Name"].str.replace(r"[^\w]", "", regex=True)
sample_NPPES["Provider Other Middle Name"] = sample_NPPES\
    ["Provider Other Middle Name"].str.replace(r"[^\w]", "", regex=True)

sample_CMS["Provider Last Name"] = sample_CMS\
    ["Provider Last Name"].str.replace(r"[^\w]", "", regex=True)
sample_CMS["Provider First Name"] = sample_CMS\
    ["Provider First Name"].str.replace(r"[^\w]", "", regex=True)
sample_CMS["Provider Middle Name"] = sample_CMS\
    ["Provider Middle Name"].str.replace(r"[^\w]", "", regex=True)


#standardize specialty names so CMS & NPPES data match better
sample_NPPES["Healthcare Provider Taxonomy Code_1"] = sample_NPPES\
    ["Healthcare Provider Taxonomy Code_1"]\
    .str.replace("Physician/","", regex=False)\
    .str.replace("(","", regex=False)\
    .str.replace(")","", regex=False)\
    .str.replace("&"," ", regex=False)\
    .str.replace("-"," ", regex=False)\
    .str.replace("/"," ", regex=False).str.upper()

replacements = {"UNDEFINED PHYSICIAN TYPE[6]":None, \
                "PSYCHOLOGIST, CLINICAL": "CLINICAL PSYCHOLOGIST",\
                "BODY IMAGING PHYSICIAN":"DIAGNOSTIC RADIOLOGY"}

sample_NPPES["Healthcare Provider Taxonomy Code_1"] = sample_NPPES\
    ["Healthcare Provider Taxonomy Code_1"].replace(replacements)

sample_CMS["pri_spec"] = sample_CMS["pri_spec"]\
    .str.replace("(","", regex=False)\
    .str.replace(")","", regex=False)\
    .str.replace("&"," ", regex=False)\
    .str.replace("-"," ", regex=False)\
    .str.replace("/"," ", regex=False).str.upper()


# output final clean files
sample_NPPES.to_csv("clean_NPPES_sample.csv", index=False)
sample_CMS.to_csv("clean_CMS_sample.csv", index=False)