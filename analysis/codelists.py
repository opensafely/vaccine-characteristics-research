from cohortextractor import (
    codelist,
    codelist_from_csv,
)
# read in VTE codelists 
vte_codes_classified = codelist_from_csv(
    "codelists/opensafely-vte-classified-codes.csv",
    system="ctv3",
    column="CTV3Code",
    category_column="Type",
)

vte_codes_hospital = codelist_from_csv(
    "codelists/opensafely-venous-thromboembolism-past-by-type-secondary-care-and-mortality-data.csv",
    system="icd10",
    column="code",
    category_column="type",
)
# codelists for covariates 
ethnicity_codes = codelist_from_csv(
    "codelists/opensafely-ethnicity.csv",
    system="ctv3",
    column="Code",
    category_column="Grouping_6",
)
lung_cancer_codes = codelist_from_csv(
    "codelists/opensafely-lung-cancer.csv", system="ctv3", column="CTV3ID",
)

haem_cancer_codes = codelist_from_csv(
    "codelists/opensafely-haematological-cancer.csv", system="ctv3", column="CTV3ID",
)

other_cancer_codes = codelist_from_csv(
    "codelists/opensafely-cancer-excluding-lung-and-haematological.csv",
    system="ctv3",
    column="CTV3ID",
)

af_codes = codelist_from_csv(
    "codelists/opensafely-atrial-fibrillation-or-flutter.csv",
    system="ctv3",
    column="CTV3Code",
)
