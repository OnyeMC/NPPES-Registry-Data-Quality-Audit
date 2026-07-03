# -*- coding: utf-8 -*-
"""
Created on Sat Jun 20 12:59:55 2026

@author: MaryClara Onyedinma

Reducing Original Datasets to Create Sample
"""

import pandas as pd
import re

#select section of rows from monthly NPPES data
chunk = pd.read_csv("npidata_pfile.csv", chunksize=50000, dtype="str",\
                    usecols=[*range(0,3), *range(4,12), *range(13,19),\
                             *range(28,34), 37, 41, 47])
chunk_df = next(chunk)


#filter section to include only providers (Entity Type Code 1)
provider_data = chunk_df[chunk_df["Entity Type Code"] == "1"]


#get NPI list from CMS data
CMS_data = pd.read_csv("CMS_data.csv", dtype="str",\
                       usecols=[0,*range(3,9),11,18,*range(21,27),30])
npi_list = CMS_data["NPI"].dropna().unique()


#reduce NPPES data list to include only those in CMS
filtered_provider_data = provider_data[provider_data["NPI"].isin(npi_list)]


#select random sample of 5000 providers
NPPES_sample = filtered_provider_data.sample(n=5000)


#get NPI list from NPPES sample to reduce CMS file
npi_list2 = NPPES_sample["NPI"]
filtered_CMS_providers = CMS_data[CMS_data["NPI"].isin(npi_list2)]


#checks for duplicates
print(NPPES_sample["NPI"].value_counts())
print(filtered_CMS_providers["NPI"].value_counts())


#remove periods from all columns
NPPES_sample = NPPES_sample.map(lambda x: x.replace(".", "") \
                                if isinstance(x, str) else x)
filtered_CMS_providers = filtered_CMS_providers.map(lambda x: \
                                                    x.replace('.', '')\
                                                    if isinstance\
                                                        (x, str) \
                                                        else x)

    
# standardize addresses
def abbrev_st_name(street_name):
    if pd.isna(street_name):
        return ""
    
    street = street_name.upper()
    abbreviations = {"STREET": "ST", "AVENUE": "AVE", "ROAD": "RD",
        "BOULEVARD": "BLVD", "DRIVE": "DR", "LANE": "LN", 
        "COURT": "CT","PLACE": "PL", "TERRACE": "TER", "PARKWAY": "PKWY", 
        "HIGHWAY": "HWY", "SUITE":"STE", "NORTH": "N", "SOUTH": "S",
        "EAST": "E", "WEST": "W", "NORTHEAST": "NE", "NORTHWEST": "NW",
        "SOUTHEAST": "SE", "SOUTHWEST": "SW", "ROOM":"RM"}
    
    for full_word, abbrev in abbreviations.items():
        pattern = r"\b" + re.escape(full_word) + r"\b"
        street = re.sub(pattern, abbrev, street, flags=re.IGNORECASE)
        
    return re.sub(r"\s+", " ", street).strip()

NPPES_sample["Provider First Line Business Practice Location Address"] =\
    NPPES_sample["Provider First Line Business Practice Location Address"].apply(abbrev_st_name)
NPPES_sample["Provider Second Line Business Practice Location Address"]\
    = NPPES_sample["Provider Second Line Business Practice Location Address"].apply(abbrev_st_name)

filtered_CMS_providers["adr_ln_1"] = filtered_CMS_providers\
    ["adr_ln_1"].apply(abbrev_st_name)
filtered_CMS_providers["adr_ln_2"] = filtered_CMS_providers\
    ["adr_ln_2"].apply(abbrev_st_name)
    

# converts taxonomy codes to specialty
all_taxonomies = pd.read_csv("Medicare_Provider_Taxonomies.csv", dtype="str")
taxo_codes = all_taxonomies["PROVIDER TAXONOMY CODE"].str.strip().str.upper()
taxo_desc = all_taxonomies["MEDICARE PROVIDER/SUPPLIER TYPE DESCRIPTION"].str.strip().str.title()
taxo_dict = dict(zip(taxo_codes, taxo_desc))

def taxo_to_specialty(taxon):
    if pd.isna(taxon):
        return ""
    else:
        taxon = taxon.strip().upper()
        return taxo_dict.get(taxon, taxon)
    # taxonomy codes that could not be replaced will be manually entered

NPPES_sample["Healthcare Provider Taxonomy Code_1"] = \
    NPPES_sample["Healthcare Provider Taxonomy Code_1"].apply(taxo_to_specialty)


# output final files
NPPES_sample.to_csv("final_NPPES_sample.csv", index=False)
filtered_CMS_providers.to_csv("final_CMS_sample.csv", index=False)