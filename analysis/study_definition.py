# Import necessary functions

from cohortextractor import (
    StudyDefinition,
    patients,
    codelist_from_csv,
    codelist,
    filter_codes_by_category,
    combine_codelists
)

# Import all codelists

from codelists import *

# Specifiy study definition

study = StudyDefinition(
    # configure the expectations framework
    default_expectations={
        "date": {"earliest": "1900-01-01", "latest": "today"},
        "rate": "uniform",
        "incidence" : 0.2
    },

    # the index date will be a persons first date of a COVID vaccine, but I need to define an index date for the expectations in the dummy data as dynamic dates currently not allowed 
    index_date="2020-12-07",

    # select the study population
    population=patients.satisfying(
        """
        (age >= 16 AND age < 105) AND 
        (sex = "M" OR sex = "F") AND 
        is_registered_with_tpp AND 
        has_follow_up AND 
        NOT has_died AND 
        any_covid_vaccine_date
        """,
    ),
    
    # define and select variables

    # COVID VACCINATION  
    # any COVID vaccination (first dose)
    any_covid_vaccine_date=patients.with_tpp_vaccination_record(
        target_disease_matches="SARS-2 CORONAVIRUS",
        on_or_after="2020-12-07",  
        find_first_match_in_period=True,
        returning="date",
        date_format="YYYY-MM-DD",
        return_expectations={
            "date": {
                "earliest": "2020-12-08",  # first vaccine administered on the 8/12
                "latest": "2021-05-01",
            }
        },
    ),
    # pfizer (first dose) 
    pfizer_covid_vaccine_date=patients.with_tpp_vaccination_record(
        target_disease_matches="SARS-2 CORONAVIRUS",
        product_name_matches="COVID-19 mRNA Vac BNT162b2 30mcg/0.3ml conc for susp for inj multidose vials (Pfizer-BioNTech)",
        on_or_after="2020-12-07",  
        find_first_match_in_period=True,
        returning="date",
        date_format="YYYY-MM-DD",
        return_expectations={
            "date": {
                "earliest": "2020-12-08",  # first vaccine administered on the 8/12
                "latest": "2021-05-01",
            }
        },
    ),
    # az (first dose)
    az_covid_vaccine_date=patients.with_tpp_vaccination_record(
        target_disease_matches="SARS-2 CORONAVIRUS",
        product_name_matches="COVID-19 Vac AstraZeneca (ChAdOx1 S recomb) 5x10000000000 viral particles/0.5ml dose sol for inj MDV",
        on_or_after="2020-12-07",  
        find_first_match_in_period=True,
        returning="date",
        date_format="YYYY-MM-DD",
        return_expectations={
            "date": {
                "earliest": "2020-12-08",  # first vaccine administered on the 8/12
                "latest": "2021-05-01",
            }
        },
    ),

    # ADMINISTRATIVE 

    # currently registered 
    is_registered_with_tpp=patients.registered_as_of(
     "any_covid_vaccine_date"
    ),
    # died before administration of vaccine 
    has_died=patients.died_from_any_cause(
      on_or_before="any_covid_vaccine_date",
      returning="binary_flag",
    ),
    # has one year of follow-up 
    has_follow_up=patients.registered_with_one_practice_between(
       start_date="any_covid_vaccine_date - 1 year",
       end_date="any_covid_vaccine_date",
       return_expectations={"incidence": 0.95},
    ),
    ## deregistration (censor) date
    dereg_date=patients.date_deregistered_from_all_supported_practices(
        on_or_after="any_covid_vaccine_date", date_format="YYYY-MM",
    ),

    # HOUSEHOLD INFORMATION
    ## care home status 
    care_home_type=patients.care_home_status_as_of(
        "any_covid_vaccine_date",
        categorised_as={
            "CareHome": """
              IsPotentialCareHome
              AND LocationDoesNotRequireNursing='Y'
              AND LocationRequiresNursing='N'
            """,
            "NursingHome": """
              IsPotentialCareHome
              AND LocationDoesNotRequireNursing='N'
              AND LocationRequiresNursing='Y'
            """,
            "CareOrNursingHome": "IsPotentialCareHome",
            "PrivateHome": "NOT IsPotentialCareHome",
            "": "DEFAULT",
        },
        return_expectations={
            "rate": "universal",
            "category": {"ratios": {"CareHome": 0.30, "NursingHome": 0.10, "CareOrNursingHome": 0.10, "PrivateHome":0.45, "":0.05},},
        },
    ),

    # DEMOGRAPHICS  
    ## age 
    age=patients.age_as_of(
        "any_covid_vaccine_date",
        return_expectations={
            "rate": "universal",
            "int": {"distribution": "population_ages"},
        },
    ),
    ## sex 
    sex=patients.sex(
        return_expectations={
            "rate": "universal",
            "category": {"ratios": {"M": 0.49, "F": 0.51}},
        }
    ),
    ## self-reported ethnicity 
    ethnicity=patients.with_these_clinical_events(
        ethnicity_codes,
        returning="category",
        find_last_match_in_period=True,
        include_date_of_match=True,
        return_expectations={
            "category": {"ratios": {"1": 0.5, "2": 0.2, "3": 0.1, "4": 0.1, "5": 0.1}},
            "incidence": 0.75,
        },
    ), 
    ## bmi 
    bmi=patients.most_recent_bmi(
        between=["any_covid_vaccine_date - 10 years", "any_covid_vaccine_date"],
        minimum_age_at_measurement=16,
        return_expectations={
            "date": {},
            "float": {"distribution": "normal", "mean": 28, "stddev": 10},
            "incidence": 0.95,
        },
    ), 
    # GEOGRAPHICAL VARIABLES 
    ## index of multiple deprivation, estimate of SES based on patient post code 
    imd=patients.categorised_as(
        {
            "0": "DEFAULT",
            "1": """index_of_multiple_deprivation >=1 AND index_of_multiple_deprivation < 32844*1/5""",
            "2": """index_of_multiple_deprivation >= 32844*1/5 AND index_of_multiple_deprivation < 32844*2/5""",
            "3": """index_of_multiple_deprivation >= 32844*2/5 AND index_of_multiple_deprivation < 32844*3/5""",
            "4": """index_of_multiple_deprivation >= 32844*3/5 AND index_of_multiple_deprivation < 32844*4/5""",
            "5": """index_of_multiple_deprivation >= 32844*4/5 AND index_of_multiple_deprivation < 32844""",
        },
        index_of_multiple_deprivation=patients.address_as_of(
            "any_covid_vaccine_date",
            returning="index_of_multiple_deprivation",
            round_to_nearest=100,
        ),
        return_expectations={
            "rate": "universal",
            "category": {
                "ratios": {
                    "0": 0.05,
                    "1": 0.19,
                    "2": 0.19,
                    "3": 0.19,
                    "4": 0.19,
                    "5": 0.19,
                }
            },
        },
    ),

    # VTE  

    ## dvt 
    dvt_gp=patients.with_these_clinical_events(
        filter_codes_by_category(vte_codes_classified, include=["dvt"]),
        returning="date", 
        date_format="YYYY-MM-DD",
        on_or_before="any_covid_vaccine_date - 1 day",
        find_last_match_in_period=True,
        return_expectations={"date": {"latest": "index_date"}},
    ),
    dvt_hospital=patients.admitted_to_hospital(
        returning="date_admitted",
        with_these_diagnoses=filter_codes_by_category(vte_codes_hospital, include=["dvt"]),
        on_or_before="any_covid_vaccine_date - 1 day",
        date_format="YYYY-MM-DD",
        find_last_match_in_period=True,
        return_expectations={"date": {"latest": "index_date"}},
    ),
    dvt=patients.satisfying("dvt_gp OR dvt_hospital"),
    ## pe
    pe_gp=patients.with_these_clinical_events(
        filter_codes_by_category(vte_codes_classified, include=["pe"]),
        returning="date", 
        date_format="YYYY-MM-DD",
        on_or_before="any_covid_vaccine_date - 1 day",
        find_last_match_in_period=True,
        return_expectations={"date": {"latest": "index_date"}},
    ),
    pe_hospital=patients.admitted_to_hospital(
        returning="date_admitted",
        with_these_diagnoses=filter_codes_by_category(vte_codes_hospital, include=["pe"]),
        on_or_before="any_covid_vaccine_date - 1 day",
        date_format="YYYY-MM-DD",
        find_last_match_in_period=True,
        return_expectations={"date": {"latest": "index_date"}},
    ),
    pe=patients.satisfying("pe_gp OR pe_hospital"),
    ##cvt 
    cvt_vte_gp=patients.with_these_clinical_events(
        filter_codes_by_category(vte_codes_classified, include=["cvt"]),
        returning="date", 
        date_format="YYYY-MM-DD",
        on_or_before="any_covid_vaccine_date - 1 day",
        find_last_match_in_period=True,
        return_expectations={"date": {"latest": "index_date"}},
    ),
    cvt_vte_hospital=patients.admitted_to_hospital(
        returning="date_admitted",
        with_these_diagnoses=filter_codes_by_category(vte_codes_hospital, include=["cvt"]),
        on_or_before="any_covid_vaccine_date - 1 day",
        date_format="YYYY-MM-DD",
        find_last_match_in_period=True,
        return_expectations={"date": {"latest": "index_date"}},
    ),
    cvt_vte=patients.satisfying("cvt_vte_gp OR cvt_vte_hospital"),
    ## portal 
    portal_vte_gp=patients.with_these_clinical_events(
        filter_codes_by_category(vte_codes_classified, include=["portal"]),
        returning="date", 
        date_format="YYYY-MM-DD",
        on_or_before="any_covid_vaccine_date - 1 day",
        find_last_match_in_period=True,
        return_expectations={"date": {"latest": "index_date"}},
    ),
    portal_vte_hospital=patients.admitted_to_hospital(
        returning="date_admitted",
        with_these_diagnoses=filter_codes_by_category(vte_codes_hospital, include=["portal"]),
        on_or_before="any_covid_vaccine_date - 1 day",
        date_format="YYYY-MM-DD",
        find_last_match_in_period=True,
        return_expectations={"date": {"latest": "index_date"}},
    ),
    portal_vte=patients.satisfying("portal_vte_gp OR portal_vte_hospital"),
    ## smv 
    smv_vte_gp=patients.with_these_clinical_events(
        filter_codes_by_category(vte_codes_classified, include=["smv"]),
        returning="date", 
        date_format="YYYY-MM-DD",
        on_or_before="any_covid_vaccine_date - 1 day",
        find_last_match_in_period=True,
        return_expectations={"date": {"latest": "index_date"}},
    ),
    ### no ICD-10 codes for SMV in hospital 
    smv_vte=patients.satisfying("smv_vte_gp"),
    ## hepatic 
    hepatic_vte_gp=patients.with_these_clinical_events(
        filter_codes_by_category(vte_codes_classified, include=["hepatic"]),
        returning="date", 
        date_format="YYYY-MM-DD",
        on_or_before="any_covid_vaccine_date - 1 day",
        find_last_match_in_period=True,
        return_expectations={"date": {"latest": "index_date"}},
    ),
    hepatic_vte_hospital=patients.admitted_to_hospital(
        returning="date_admitted",
        with_these_diagnoses=filter_codes_by_category(vte_codes_hospital, include=["hepatic"]),
        on_or_before="any_covid_vaccine_date - 1 day",
        date_format="YYYY-MM-DD",
        find_last_match_in_period=True,
        return_expectations={"date": {"latest": "index_date"}},
    ),
    hepatic_vte=patients.satisfying("hepatic_vte_gp OR hepatic_vte_hospital"),
    ## vc 
    vc_vte_gp=patients.with_these_clinical_events(
        filter_codes_by_category(vte_codes_classified, include=["vc"]),
        returning="date", 
        date_format="YYYY-MM-DD",
        on_or_before="any_covid_vaccine_date - 1 day",
        find_last_match_in_period=True,
        return_expectations={"date": {"latest": "index_date"}},
    ), 
    vc_vte_hospital=patients.admitted_to_hospital(
        returning="date_admitted",
        with_these_diagnoses=filter_codes_by_category(vte_codes_hospital, include=["vc"]),
        on_or_before="any_covid_vaccine_date - 1 day",
        date_format="YYYY-MM-DD",
        find_last_match_in_period=True,
        return_expectations={"date": {"latest": "index_date"}},
    ),
    vc_vte=patients.satisfying("vc_vte_gp OR vc_vte_hospital"),
    ## unspecified 
    unspecified_vte_gp=patients.with_these_clinical_events(
        filter_codes_by_category(vte_codes_classified, include=["unspecified"]),
        returning="date", 
        date_format="YYYY-MM-DD",
        on_or_before="any_covid_vaccine_date - 1 day",
        find_last_match_in_period=True,
        return_expectations={"date": {"latest": "index_date"}},
    ),
    unspecified_vte_hospital=patients.admitted_to_hospital(
        returning="date_admitted",
        with_these_diagnoses=filter_codes_by_category(vte_codes_hospital, include=["unspecified"]),
        on_or_before="any_covid_vaccine_date - 1 day",
        date_format="YYYY-MM-DD",
        find_last_match_in_period=True,
        return_expectations={"date": {"latest": "index_date"}},
    ),
    unspecified_vte=patients.satisfying("unspecified_vte_gp OR unspecified_vte_hospital"),
    ## other 
    other_vte_gp=patients.with_these_clinical_events(
        filter_codes_by_category(vte_codes_classified, include=["other"]),
        returning="date", 
        date_format="YYYY-MM-DD",
        on_or_before="any_covid_vaccine_date - 1 day",
        find_last_match_in_period=True,
        return_expectations={"date": {"latest": "index_date"}},
    ),
    # no other VTE ICD-10 codes 
    other_vte=patients.satisfying("other_vte_gp"),
) 



