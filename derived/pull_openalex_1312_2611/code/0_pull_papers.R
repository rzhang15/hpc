library(openalexR)
library(dplyr)
library(ggplot2)
library(here)
library(haven)
library(stringr)
library(purrr)
library(tidyverse)
set.seed(8975)

setwd("~/Documents/GitHub/hpc/derived/pull_openalex_1312_2611/code")

id_list <- c(
  "i150468666", "i200719446", "i138006243", "i86519309", "i32389192", "i66946132",
  "i859038795", "i63135867", "i188538660", "i126744593", "i204250578", "i58956616",
  "i165733156", "i122411786", "i143302722", "i63190737", "i39422238", "i92446798",
  "i20089843", "i74973139", "i173911158", "i76835614", "i121980950", "i72951846",
  "i146416000", "i2613432", "i121820613", "i84392919", "i117965899", "i59553526",
  "i184840846", "i193531525", "i154570441", "i169521973", "i86501945", "i24603500",
  "i107639228", "i189590672", "i162714631", "i74775410", "i155781252", "i142740786",
  "i12097938", "i111236770", "i103635307", "i44461941", "i8078737", "i115475287",
  "i141472210", "i57328836", "i12315562", "i185103710", "i118118575", "i161057412",
  "i78715868", "i72816309", "i7947594", "i368840534", "i165799507", "i10052268",
  "i25041050", "i12834331", "i6902469", "i181233156", "i79272384", "i70983195",
  "i133999245", "i167576493", "i11957088", "i102607778", "i44854399", "i177156846",
  "i81365321", "i123534392", "i16285277", "i43579087", "i94658018", "i83809506",
  "i63772739", "i155173764", "i19648265", "i2802326326", "i20382870", "i156087764",
  "i4210106879", "i107077323", "i120156002", "i181401687", "i100005738", "i126345244",
  "i35777872", "i102461120", "i96749437", "i178169726", "i100633361", "i44265643",
  "i189957204", "i84470341", "i87208437", "i106959904", "i250520410", "i1629065",
  "i106969075", "i165102784", "i177721651", "i166088655", "i138873065", "i39815113",
  "i67328108", "i48205209", "i142934699", "i888729015", "i131221577", "i177898655",
  "i60060512", "i115364640", "i153204768", "i177605424", "i4210086901", "i184647316",
  "i177097968", "i39965400", "i151328261", "i126548940", "i176692203", "i207123951",
  "i872719", "i64281891", "i118073183", "i184692499", "i152014189", "i16277215",
  "i86115722", "i87097829", "i70571728", "i188592606", "i27920566", "i157638225",
  "i163795733", "i106107269", "i72903472", "i32038505", "i139290212", "i11123151",
  "i139325414", "i158012942", "i145402516", "i290598920", "i195575238", "i160003610",
  "i41644977", "i51504820", "i124727415", "i104651037", "i8606887", "i165556055",
  "i142393192", "i26489229", "i208081647", "i100236772", "i4210143716", "i100538780",
  "i110357561", "i71966907", "i60388903", "i16473318"
)

process_article <- function(article) {
  if (length(article[["authorships"]]) == 0) return(NULL)
  
  ids <- rep(article[["id"]], length(article[["authorships"]]))
  abstract_len <- rep(length(article[["abstract_inverted_index"]]), length(article[["authorships"]]))
  doi <- rep(ifelse(length(article[["doi"]]) != 0, article[["doi"]], ""), length(article[["authorships"]]))
  jrnl <- rep(ifelse(length(article[["primary_location"]][["source"]][["display_name"]]) != 0, article[["primary_location"]][["source"]][["display_name"]], ""), length(article[["authorships"]]))
  title <- rep(ifelse(length(article[["title"]]) != 0, article[["title"]], ""), length(article[["authorships"]]))
  pub_date <- rep(ifelse(length(article[["publication_date"]]) != 0, article[["publication_date"]], ""), length(article[["authorships"]]))
  retracted <- rep(ifelse(length(article[["is_retracted"]]) != 0, article[["is_retracted"]], ""), length(article[["authorships"]]))
  cite_count <- rep(ifelse(length(article[["cited_by_count"]]) != 0, article[["cited_by_count"]], ""), length(article[["authorships"]]))
  pub_type <- rep(ifelse(length(article[["type"]]) != 0, article[["type"]], ""), length(article[["authorships"]]))
  pub_type_crossref <- rep(ifelse(length(article[["type_crossref"]]) != 0, article[["type_crossref"]], ""), length(article[["authorships"]]))
  pmid <- rep(ifelse(length(article[["ids"]][["pmid"]]) != 0, article[["ids"]][["pmid"]], ""), length(article[["authorships"]]))
  retracted <- rep(ifelse(length(article[["is_retracted"]]) != 0, article[["is_retracted"]], ""), length(article[["authorships"]]))
  which_athr <- seq_along(article[["authorships"]])
  
  author_data <- map_dfr(article[["authorships"]], function(authorship) {
    athr_id <- ifelse(is.null(authorship[["author"]][["id"]]), "", authorship[["author"]][["id"]])
    athr_pos <- ifelse(is.null(authorship[["author_position"]][[1]]), "", authorship[["author_position"]][[1]])
    raw_affl <- ifelse(is.null(authorship[["raw_affiliation_string"]][[1]]), "", authorship[["raw_affiliation_string"]][[1]])
    athr_name <- ifelse(is.null(authorship[["author"]][["display_name"]]), "", authorship[["author"]][["display_name"]])
    num_affls <- length(authorship[["institutions"]])
    tibble(athr_id, athr_pos, raw_affl, athr_name, num_affls)
  })
  
  bind_cols(ids, abstract_len, doi, jrnl, title, pub_date, retracted, cite_count, pub_type, pub_type_crossref, pmid, which_athr, author_data)
}
years <- 2009:2015  # Define the years you want to loop over
for (year in years) {
  # Initialize an empty list to hold works for the current year
  works_year <- list()
  
  # Loop through each institution in your id_list vector
  for (inst in id_list) {
    print(inst)
    works_temp <- oa_fetch(
      entity = "works",
      institutions.id = inst,
      publication_year = as.character(year),
      output = "list",
      topics.subfield.id = c(1312, 2611),
      type = "article"
    )
    # Combine the results from each institution
    works_year <- c(works_year, works_temp)
  }
  
  # Process the combined works from all institutions for this year
  au_ids <- map_dfr(works_year, process_article)
  colnames(au_ids) <- c("id", "abstract_len", "doi", "jrnl", "title", "pub_date", "retracted", "cite_count", 
                        "pub_type", "pub_type_crossref", "pmid", "which_athr", "athr_id", "athr_pos", 
                        "raw_affl", "athr_name", "num_affls")
  
  au_ids <- au_ids %>%
    mutate(num_affls = replace(num_affls, num_affls == 0, 1)) %>%
    uncount(num_affls)
  
  inst <- list()
  inst_id <- list()
  
  for (i in seq_along(works_year)) {
    article <- works_year[[i]]
    if (length(article[["authorships"]]) == 0) next
    
    for (authorship in article[["authorships"]]) {
      if (length(authorship[["institutions"]]) == 0) {
        inst <- append(inst, "")
        inst_id <- append(inst_id, "")
      } else {
        for (institution in authorship[["institutions"]]) {
          inst <- append(inst, ifelse(length(institution[["display_name"]]) != 0, 
                                      institution[["display_name"]], ""))
          inst_id <- append(inst_id, ifelse(length(institution[["id"]]) != 0, 
                                            institution[["id"]], ""))
        }
      }
    }
  }
  
  affl_list <- au_ids %>% 
    mutate(inst = inst, inst_id = inst_id) %>%
    group_by(id, which_athr) %>%
    mutate(which_affl = 1:n(),
           id = str_replace(as.character(id), "https://openalex.org/", ""),
           pmid = str_replace(pmid, "https://pubmed.ncbi.nlm.nih.gov/", ""),
           athr_id = str_replace(athr_id, "https://openalex.org/", ""),
           inst_id = str_replace(inst_id, "https://openalex.org/", ""))
  
  write_csv(affl_list, paste0("../output/openalex_authors", as.character(year), ".csv"))
  
  grants <- map_dfr(works_year, function(article) {
    if (length(article[["grants"]]) == 0) return(NULL)
    
    ids <- rep(article[["id"]], length(article[["grants"]]))
    which_grant <- seq_along(article[["grants"]])
    funder_id <- map_chr(article[["grants"]], "funder", .default = NA_character_)
    funder_name <- map_chr(article[["grants"]], "funder_display_name", .default = NA_character_)
    award_id <- map_chr(article[["grants"]], "award_id", .default = NA_character_)
    
    tibble(id = ids, which_grant = which_grant, funder_id = funder_id, 
           funder_name = funder_name, award_id = award_id)
  })
  
  colnames(grants) <- c("id", "which_grant", "funder_id", "funder_name", "award_id")
  
  if (nrow(grants) != 0) {
    grants <- grants %>% 
      mutate(id = str_replace(as.character(id), "https://openalex.org/", ""),
             funder_id = str_replace(as.character(funder_id), "https://openalex.org/", ""))
    write_csv(grants, paste0("../output/grants", as.character(year), ".csv"))
  }
  
  mesh_terms <- map_dfr(works_year, function(article) {
    if (length(article[["mesh"]]) == 0) return(NULL)
    
    ids <- rep(article[["id"]], length(article[["mesh"]]))
    which_mesh <- seq_along(article[["mesh"]])
    terms <- map_chr(article[["mesh"]], "descriptor_name")
    major_topic <- map_lgl(article[["mesh"]], "is_major_topic")
    qualifier <- map_chr(article[["mesh"]], ~ ifelse(is.null(.x[["qualifier_name"]]), "", .x[["qualifier_name"]]))
    
    tibble(ids, which_mesh, terms, major_topic, qualifier)
  })
  
  colnames(mesh_terms) <- c("id", "which_mesh", "term", "is_major_topic", "qualifier_name")
  
  if (nrow(mesh_terms) != 0) {
    mesh_terms <- mesh_terms %>% 
      mutate(id = str_replace(as.character(id), "https://openalex.org/", ""))
    write_csv(mesh_terms, paste0("../output/mesh_terms", as.character(year), ".csv"))
  }
  
  topics <- map_dfr(works_year, function(article) {
    if (length(article[["topics"]]) == 0) return(NULL)
    ids <- rep(article[["id"]], length(article[["topics"]]))
    which_topic <- seq_along(article[["topics"]])
    topic_id <- map_chr(article[["topics"]], "id")
    topic <- map_chr(article[["topics"]], "display_name")
    subfield_id <- map_chr(article[["topics"]], ~ .x[["subfield"]][["id"]], .default = NA_character_)
    subfield <- map_chr(article[["topics"]], ~ .x[["subfield"]][["display_name"]], .default = NA_character_)
    field_id <- map_chr(article[["topics"]], ~ .x[["field"]][["id"]], .default = NA_character_)
    field <- map_chr(article[["topics"]], ~ .x[["field"]][["display_name"]], .default = NA_character_)
    domain_id <- map_chr(article[["topics"]], ~ .x[["domain"]][["id"]], .default = NA_character_)
    domain <- map_chr(article[["topics"]], ~ .x[["domain"]][["display_name"]], .default = NA_character_)
    tibble(ids, which_topic, topic_id, topic, subfield_id, subfield, field, field_id, domain_id, domain)
  })
  
  colnames(topics) <- c("id", "which_topic", "topic_id", "topic", "subfield_id", "subfield", "field", "field_id", "domain_id", "domain")
  
  if (nrow(topics) != 0) {
    topics <- topics %>% 
      mutate(id = str_replace(as.character(id), "https://openalex.org/", ""), 
             topic_id = str_replace(as.character(topic_id), "https://openalex.org/", ""),
             subfield_id = str_replace(as.character(subfield_id), "https://openalex.org/subfields/", ""),
             field_id = str_replace(as.character(field_id), "https://openalex.org/fields/", ""),
             domain_id = str_replace(as.character(domain_id), "https://openalex.org/domains/", ""))
    write_csv(topics, paste0("../output/topics", as.character(year), ".csv"))
  }
}