# 01_limpieza.R
# Autor: Fernando S.
# Objetivo: Limpieza de datos experimental (Juego del Dictador) y preparación de df_long.csv
# Replicando lógica de Limpieza.ipynb

library(tidyverse)
library(here) # Aunque usamos rutas relativas, here es buena práctica si se corre desde proyecto

# --- CONFIGURACIÓN DE RUTAS ---
# Definimos rutas relativas desde la ubicación del script (scripts/R_FernandoS/)
path_raw <- "../../data/raw"
path_processed <- "../../data/processed"
path_out <- "../../outputs/R_FernandoS"

# Crear directorio de salida si no existe (aunque ya debería existir por infraestructura)
if (!dir.exists(path_out)) dir.create(path_out, recursive = TRUE)

# --- 1. CARGA DE DATOS ---
message("Cargando datos...")

df_res_dict <- read_csv(file.path(path_raw, "Base_res_dict.csv"), show_col_types = FALSE)
df_dem_dict <- read_csv(file.path(path_raw, "Base_Dem_dict.csv"), show_col_types = FALSE)
df_res_coop <- read_csv(file.path(path_raw, "Base_res_coop.csv"), show_col_types = FALSE)
df_info_bloques <- read_csv(file.path(path_raw, "info_bloques.csv"), show_col_types = FALSE)

# --- 2. PRE-PROCESAMIENTO INFO BLOQUES ---
# Renombrar 'Nombre' a 'Bloque' y seleccionar columnas de interés
df_info_bloques_sel <- df_info_bloques %>%
  rename(Bloque = Nombre) %>%
  select(Bloque, Gap_Size = `Diferencia desigualdad final entre opciones`) # Ya renombramos Gap_Size aquí para facilitar

# --- 3. LIMPIEZA (ATENCIÓN) ---
message("Identificando fallos de atención...")

# Identificar fallos en Bloque_0
failed_ids <- df_res_dict %>%
  filter(Bloque == "Bloque_0", Respuesta != "Opción 3") %>%
  pull(ID_Sujeto) %>%
  unique()

message(paste("Sujetos eliminados por atención:", length(failed_ids)))

# Filtrar dataframes
df_res_clean <- df_res_dict %>%
  filter(!ID_Sujeto %in% failed_ids) %>%
  filter(Bloque != "Bloque_0", Dilema != "Atencion")

df_dem_clean <- df_dem_dict %>%
  filter(!ID_Sujeto %in% failed_ids)

# (Opcional: Filtrar coop aunque no se use en el final)
df_coop_clean <- df_res_coop %>%
  filter(!ID_Sujeto %in% failed_ids)

message(paste("Muestra final limpia (sujetos):", n_distinct(df_res_clean$ID_Sujeto)))

# --- 4. CREACIÓN DE VARIABLES (RESULTADOS) ---
# Variable Mantiene: 1 si Opción 1, 0 si no
df_res_clean <- df_res_clean %>%
  mutate(Mantiene = if_else(Respuesta == "Opción 1", 1, 0))

# --- 5. CREACIÓN DE VARIABLES (DEMOGRÁFICOS) ---
# Mapeo de expectativas
mapeo_expectativas <- c(
  "No espero ningún efecto" = 0,
  "La Opción 1 incrementa la probabilidad de cooperación" = 1,
  "La opción 1 incrementa la posibilidad de cooperación" = 1,
  "La Opción 2 incrementa la probabilidad de cooperación" = -1,
  "La opción 2 incrementa la posibilidad de cooperación" = -1
)

cols_expectativas <- c("expectativa_sin", "expectativa_grande", "expectativa_pequeña")

# Aplicar reemplazo y convertir a numérico
df_dem_clean <- df_dem_clean %>%
  mutate(across(all_of(cols_expectativas), ~as.numeric(recode(., !!!mapeo_expectativas))))

# Calcular Scores Psicométricos (SDO y NDC)
# Asumimos columnas que contienen "sdo_" y "ndc_"
df_dem_clean <- df_dem_clean %>%
  rowwise() %>%
  mutate(
    SDO_Score = mean(c_across(starts_with("sdo_")), na.rm = TRUE),
    NDC_Score = mean(c_across(starts_with("ndc_")), na.rm = TRUE)
  ) %>%
  ungroup()

# --- 6. MERGE FINAL (MASTER) ---
cols_demograficas <- c("ID_Sujeto", "SDO_Score", "NDC_Score",
                       "expectativa_sin", "expectativa_grande", "expectativa_pequeña",
                       "Genero", "politica", "nivel_se")

df_master <- df_res_clean %>%
  left_join(df_dem_clean %>% select(all_of(cols_demograficas)), by = "ID_Sujeto") %>%
  left_join(df_info_bloques_sel, by = "Bloque")

# --- 7. EXPECTATIVA ACTIVA ---
# Crear versiones numéricas (rellenando NA con 0 si fuera necesario, aunque aquí ya son numéricas o NA)
# En el python fillna(0) se aplicaba a las columnas numéricas.
# Aquí creamos columnas _num asumiendo 0 si es NA (según lógica python)
for(col in cols_expectativas) {
  df_master[[paste0(col, "_num")]] <- replace_na(df_master[[col]], 0)
}

df_master <- df_master %>%
  mutate(Expectativa_Activa = case_when(
    Bloque %in% c("Bloque_1", "Bloque_3") ~ expectativa_sin_num,
    Bloque %in% c("Bloque_5", "Bloque_7") ~ expectativa_grande_num,
    Bloque %in% c("Bloque_9", "Bloque_11") ~ expectativa_pequeña_num,
    TRUE ~ NA_real_
  ))

# --- 8. CÁLCULO DE PROMEDIOS POR GAP (PIVOT) ---
df_gaps <- df_master %>%
  group_by(ID_Sujeto, Gap_Size) %>%
  summarise(Mantiene_Mean = mean(Mantiene, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = Gap_Size, values_from = Mantiene_Mean, names_prefix = "Promedio_Gap_")

# Unir al master
df_master <- df_master %>%
  left_join(df_gaps, by = "ID_Sujeto")

# --- 9. CÁLCULO DE DELTAS ---
df_wide_dilema <- df_master %>%
  group_by(ID_Sujeto, Dilema) %>%
  summarise(Mantiene_Mean = mean(Mantiene, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = Dilema, values_from = Mantiene_Mean, names_prefix = "Promedio_")

# En python: Promedio_CON = Bloque_CON, Promedio_SIN = Bloque_SIN, Promedio_DIST = Dist
# Ajustamos nombres para coincidir con python logic
# Si las columnas generadas son Promedio_Bloque_CON, Promedio_Bloque_SIN, Promedio_Dist
df_wide_dilema <- df_wide_dilema %>%
  mutate(
    Promedio_CON = `Promedio_Bloque_CON`,
    Promedio_SIN = `Promedio_Bloque_SIN`,
    Promedio_DIST = `Promedio_Dist`,
    Delta_Mantiene = Promedio_CON - Promedio_SIN,
    Delta_base = Promedio_SIN - Promedio_DIST
  ) %>%
  select(ID_Sujeto, Promedio_CON, Promedio_SIN, Promedio_DIST, Delta_Mantiene, Delta_base)

# Unir Deltas al Master
df_long1 <- df_master %>%
  left_join(df_wide_dilema, by = "ID_Sujeto")

# --- 10. FILTRO DE GÉNERO ---
generos_validos <- c("Mujer", "Hombre")
df_long <- df_long1 %>%
  filter(Genero %in% generos_validos)

message(paste("Sujetos finales después de filtro de género:", n_distinct(df_long$ID_Sujeto)))
message("Distribución de género:")
print(table(df_long$Genero))

# --- 11. GUARDAR DATOS ---
# Guardar df_long en processed (para compatibilidad con Python)
file_out <- file.path(path_processed, "df_long.csv")
write_csv(df_long, file_out)
message(paste("Archivo guardado en:", file_out))

# Generar un output adicional de prueba (tabla resumen) para la carpeta de R
tabla_resumen <- df_long %>%
  group_by(Bloque, Dilema) %>%
  summarise(
    N = n(),
    Mantiene_Pct = mean(Mantiene),
    SDO_Promedio = mean(SDO_Score, na.rm=TRUE),
    .groups = "drop"
  )

file_summary <- file.path(path_out, "resumen_limpieza.csv")
write_csv(tabla_resumen, file_summary)
message(paste("Resumen guardado en:", file_summary))
