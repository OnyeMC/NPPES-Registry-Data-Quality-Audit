--NPPES Provider Data Audit Project
--MaryClara Onyedinma

--Timeliness
--- percentages for how long ago the table was updated (in 5 year brackets)
CREATE VIEW last_update_percentage AS
WITH recency AS (
    SELECT 
        CASE WHEN DATE_PART('year', AGE(CURRENT_DATE, last_update_date)) < 5 
                THEN '0–5 years'
            WHEN DATE_PART('year', AGE(CURRENT_DATE, last_update_date)) < 10 
                THEN '5–10 years'
            WHEN DATE_PART('year', AGE(CURRENT_DATE, last_update_date)) < 15 
                THEN '10–15 years'
            ELSE '15+ years' END AS last_update_range
    FROM nppes_sample
)
SELECT 
    last_update_range,
    (COUNT(*) * 100.0)/5000 AS percentage
FROM recency
GROUP BY last_update_range
ORDER BY 
    CASE last_update_range
        WHEN '0–5 years' THEN 1
        WHEN '5–10 years' THEN 2
        WHEN '10–15 years' THEN 3
        WHEN '15+ years' THEN 4
    END;

---last update ranges by provider npi
CREATE npi_last_update_ranges AS
SELECT npi,
    CASE WHEN DATE_PART('year', AGE(CURRENT_DATE, last_update_date)) < 5 THEN '0–5 years'
        WHEN DATE_PART('year', AGE(CURRENT_DATE, last_update_date)) < 10 THEN '5–10 years'
        WHEN DATE_PART('year', AGE(CURRENT_DATE, last_update_date)) < 15 THEN '10–15 years'
        ELSE '15+ years' END AS last_update_range
FROM nppes_sample;

--Completeness
--- Number of rows missing important information
CREATE VIEW null_values_by_npi AS
SELECT npi,
    CASE 
        WHEN npi IS NULL THEN 'npi'
        WHEN last_name IS NULL THEN 'last_name'
        WHEN first_name IS NULL THEN 'first_name'
        WHEN middle_name IS NULL THEN 'middle_name'
        WHEN credential IS NULL THEN 'credential'
        WHEN full_street_address IS NULL THEN 'full_street_address'
        WHEN city IS NULL THEN 'city'
        WHEN state IS NULL THEN 'state'
        WHEN zip_code IS NULL THEN 'zip_code'
        WHEN country IS NULL THEN 'country'
        WHEN gender IS NULL THEN 'gender'
        WHEN primary_specialty IS NULL THEN 'primary_specialty'
    END AS null_field
FROM nppes_sample
WHERE npi IS NULL
    OR last_name IS NULL
    OR first_name IS NULL
    OR middle_name IS NULL
    OR credential IS NULL
    OR full_street_address IS NULL
    OR city IS NULL
    OR state IS NULL
    OR zip_code IS NULL
    OR country IS NULL
    OR gender IS NULL
    OR primary_specialty IS NULL;

--Accuracy
---for similarity
CREATE EXTENSION IF NOT EXISTS pg_trgm;

---gender mismatches
CREATE VIEW gender_mismatches AS
SELECT DISTINCT ON (n.npi)
	n.npi,
	n.gender AS nppes_gender,
	c.gender AS cms_gender
FROM nppes_sample n
JOIN cms_sample c ON n.npi = c.npi
WHERE NOT EXISTS (
    SELECT 1
    FROM cms_sample c2
	WHERE c2.npi = n.npi
      AND c2.gender = n.gender
	   );

---credential mismatches
CREATE VIEW credential_mismatches AS
WITH nppes_split AS (
    SELECT 
        n.npi,
        regexp_split_to_table(n.credential, '\s*,\s*') AS nppes_cred
    FROM nppes_sample n
    WHERE n.credential IS NOT NULL
),
cms_split AS (
    SELECT 
        c.npi,
        regexp_split_to_table(c.credential, '\s*,\s*') AS cms_cred
    FROM cms_sample c
    WHERE c.credential IS NOT NULL
),
credential_matches AS (
    SELECT DISTINCT n.npi
    FROM nppes_split n
    JOIN cms_split c ON n.npi = c.npi
    WHERE 
		(
	     (n.nppes_cred = 'DC' AND c.cms_cred = 'CH') OR
	     (n.nppes_cred = 'CH' AND c.cms_cred = 'DC')
	    ) OR
		similarity(n.nppes_cred, c.cms_cred) > 0.3
),
credential_mismatches AS (
    SELECT DISTINCT n.npi
    FROM nppes_split n
    JOIN cms_split c ON n.npi = c.npi
    WHERE n.npi NOT IN (SELECT npi FROM credential_matches)
)
SELECT DISTINCT ON (n.npi)
    n.npi,
    n.credential AS nppes_credential,
    c.credential AS cms_credential,
FROM nppes_sample n
JOIN cms_sample c ON n.npi = c.npi
WHERE n.npi IN (SELECT npi FROM credential_mismatches)
ORDER BY n.npi, c.credential;

---last name mismatches
CREATE VIEW last_name_mismatches AS
SELECT DISTINCT ON (n.npi)
	n.npi, 
	n.last_name AS nppes_last_name,
	n.other_last_name AS nppes_other_last_name,
	c.last_name AS cms_last_name
FROM nppes_sample n
JOIN cms_sample c ON n.npi = c.npi
WHERE NOT EXISTS (
    SELECT 1
    FROM cms_sample c2
	WHERE (c2.npi = n.npi)
      AND (c2.last_name = n.last_name
       		OR c2.last_name = n.other_last_name)
	   );

---first name mismatches
CREATE VIEW first_name_mismatches AS
SELECT DISTINCT ON (n.npi)
	n.npi, 
	n.first_name AS nppes_first_name,
	n.other_first_name AS nppes_other_first_name,
	c.first_name AS cms_first_name
FROM nppes_sample n
JOIN cms_sample c ON n.npi = c.npi
WHERE NOT EXISTS (
    SELECT 1
    FROM cms_sample c2
	WHERE (c2.npi = n.npi)
      AND (c2.first_name = n.first_name
       		OR c2.first_name = n.other_first_name)
	   );

---middle name mismatches (by initial or full name)
CREATE VIEW middle_name_mismatches AS
SELECT DISTINCT ON (n.npi)
    n.npi, 
    n.middle_name AS nppes_middle_name,
    n.other_middle_name AS nppes_other_middle_name,
    c.middle_name AS cms_middle_name
FROM nppes_sample n
JOIN cms_sample c ON n.npi = c.npi
WHERE 
    NOT EXISTS (
        SELECT 1
        FROM cms_sample cnull
        WHERE cnull.npi = n.npi
          AND cnull.middle_name IS NULL
    )
    AND NOT (
        n.middle_name IS NULL 
        AND n.other_middle_name IS NULL
    )
    AND NOT EXISTS (
        SELECT 1
        FROM cms_sample c2
        WHERE c2.npi = n.npi
          AND (
                (
                    n.middle_name IS NOT NULL
                    AND (
                        (LENGTH(n.middle_name) > 1 AND LENGTH(c2.middle_name) > 1 AND n.middle_name = c2.middle_name)
                        OR LEFT(n.middle_name, 1) = LEFT(c2.middle_name, 1)
                    )
                )
                OR
                (
                    n.other_middle_name IS NOT NULL
                    AND (
                        (LENGTH(n.other_middle_name) > 1 AND LENGTH(c2.middle_name) > 1 AND n.other_middle_name = c2.middle_name)
                        OR LEFT(n.other_middle_name, 1) = LEFT(c2.middle_name, 1)
                    )
                )
              )
    )
ORDER BY n.npi, c.middle_name;

---primary specialty mismatches
CREATE VIEW specialty_mismatches AS
WITH best_spec_match AS (
    SELECT DISTINCT ON (n.npi)
        n.npi,
        n.primary_specialty AS nppes_specialty,
        c.primary_specialty AS cms_specialty,
        similarity(n.primary_specialty, c.primary_specialty) AS sim
    FROM nppes_sample n
    JOIN cms_sample c ON n.npi = c.npi
    ORDER BY 
        n.npi,
        similarity(n.primary_specialty, c.primary_specialty) DESC
)
SELECT 
    npi,
    nppes_specialty,
    cms_specialty
FROM best_spec_match
WHERE sim < 0.3
ORDER BY sim ASC;

---address mismatches
CREATE VIEW address_mismatches AS
WITH best_address_match AS (
    SELECT DISTINCT ON (n.npi)
        n.npi,
        n.full_street_address AS nppes_address,
        n.city AS nppes_city,
        n.state AS nppes_state,
        n.zip_code AS nppes_zip,
        c.full_street_address AS cms_address,
        c.city AS cms_city,
        c.state AS cms_state,
        c.zip_code AS cms_zip,
        similarity(n.full_street_address, c.full_street_address) AS sim_addr,
        similarity(n.city, c.city) AS sim_city,
        similarity(n.state, c.state) AS sim_state,
        similarity(n.zip_code, c.zip_code) AS sim_zip
    FROM nppes_sample n
    JOIN cms_sample c 
        ON n.npi = c.npi
    ORDER BY 
        n.npi,
        (
            similarity(n.full_street_address, c.full_street_address) +
            similarity(n.city, c.city) +
            similarity(n.state, c.state) +
            similarity(n.zip_code, c.zip_code)
        ) DESC
)
SELECT 
    npi,
    nppes_address,
    cms_address,
	sim_addr,
    nppes_city,
    cms_city,
	sim_city,
    nppes_state,
    cms_state,
	sim_state,
    nppes_zip,
    cms_zip,
    sim_zip
FROM best_address_match
WHERE 
    sim_addr < 0.75
    OR sim_city < 0.75
    OR sim_state < 0.75
    OR sim_zip < 0.75
ORDER BY 
    sim_addr + sim_city + sim_state + sim_zip ASC;


--Validity
---invalid credentials
CREATE VIEW invalid_credential AS
SELECT n.npi, n.credential
FROM nppes_sample n
CROSS JOIN LATERAL (
    SELECT regexp_split_to_table(regexp_replace(
            regexp_replace(UPPER(n.credential), '[,/\-]', ' ', 'g'), '[^\w\s]', '', 'g'), '\s+'
    ) AS word
) w
WHERE w.word IS NOT NULL
GROUP BY n.npi, n.credential
HAVING COUNT(*) FILTER (
    WHERE EXISTS (
        SELECT 1 
        FROM valid_credentials c 
        WHERE w.word = UPPER(c.cred_abbrev)
           OR w.word % UPPER(c.cred_abbrev)
    )
) = 0;

--- list of prefixes & suffixes commonly included
--- I did not create a view for these queries since no incorrect results were found
SELECT combined_prefix, COUNT(*) AS total_count
FROM (
    SELECT name_prefix AS combined_prefix FROM nppes_sample
    UNION ALL
    SELECT other_name_prefix AS combined_prefix FROM nppes_sample
) subquery
WHERE combined_prefix IS NOT NULL
GROUP BY combined_prefix
ORDER BY total_count;

SELECT combined_suffix, COUNT(*) AS total_count
FROM (
    SELECT name_suffix AS combined_suffix FROM nppes_sample
    UNION ALL
    SELECT other_name_suffix AS combined_suffix FROM nppes_sample
) subquery
WHERE combined_suffix IS NOT NULL
GROUP BY combined_suffix
ORDER BY total_count;

--- Invalid addresses
----No street number or organization name listed under first address line
CREATE VIEW invalid_address_issue AS
SELECT npi, full_street_address
FROM  nppes_sample
WHERE full_street_address NOT SIMILAR TO '[0-9]%';