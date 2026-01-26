# Análisis de Arreglos Estratégicos (arr-estrategico)

Repositorio para el análisis de datos experimentales del proyecto de investigación. Este repositorio contiene el flujo completo desde la limpieza de datos crudos hasta el análisis de efectos específicos (Tratamiento, Gap y Expectativas).

## 📂 Estructura del Proyecto

### 1. Preprocesamiento y Limpieza
* **`Limpieza.ipynb`**: Notebook principal. Toma las bases crudas, anonimiza sujetos y genera los dataframes procesados (como `df_long` y `df_expectativas_filtrada`).
* **`Diccionario de Datos`**: Documento de referencia con la definición de variables y códigos utilizados.

### 2. Análisis Estadísticos (Notebooks)
Una vez limpios los datos, el análisis se divide en tres ejes principales:
* **`Efecto tratamiento.ipynb`**: Análisis del impacto de los bloques experimentales principales.
* **`Efecto Gap.ipynb`**: Evaluación de la variable de costo/diferencia (Gap Size).
* **`Efecto expectativas.ipynb`**: Análisis específico sobre cómo las expectativas influyen en la decisión (usando `df_expectativas_filtrada`).

### 3. Datos Procesados (Outputs)
* **`df_long`**: Base de datos consolidada en formato largo (panel data) lista para modelos de regresión.
* **`df_expectativas_filtrada`**: Subconjunto de datos filtrado para el análisis de expectativas.
* **`Base_Dem_dict` / `Base_res_dict`**: Diccionarios de datos demográficos y de resultados.

### 4. Visualización de Resultados
* **`panel_completo_resultados.png`**: Vista general consolidada de los hallazgos principales.
* **`grafico_barras_gap.png`**: Visualización específica de la distribución por Gap.

---
**Nota:** El archivo `borr4dor.ipynb` es un espacio de trabajo temporal para pruebas de código.
