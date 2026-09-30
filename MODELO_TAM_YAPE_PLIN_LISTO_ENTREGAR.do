/*==============================================================================
  DO-FILE: ANÁLISIS TAM - YAPE/PLIN
  Autora  : Keila Bocanegra
  Proyecto: Modelo TAM - Adopción de billeteras digitales (Perú)
  Datos   : raw_data3_fixed.csv
  Fecha   : Junio 2026
  Versión : 2.0 (corregida — sin influencia_cultural, SEM limpio)

  MODELO ESTRUCTURAL:
    FacilidadUso  → Actitud          (H1)
    Utilidad      → Actitud          (H2)
    Utilidad      → IntencionUso     (H3)
    Actitud       → IntencionUso     (H4)
    Seguridad     → IntencionUso     (H5)
    Confianza     → IntencionUso     (H6)
    IntencionUso  → ValorAnadido     (H7)

  NOTA METODOLÓGICA:
    - influencia_cultural fue eliminada: el cuestionario no contiene ítems
      que la midan de forma independiente. Incluirla creaba una variable
      proxy de IntenciónUso, inflando artificialmente R² (~0.80) y
      generando coeficientes no interpretables.
    - El SEM estima MLMV (full-information ML con valores perdidos).
    - El AFC precede al SEM para verificar validez de constructo.
==============================================================================*/

clear all
set more off
set linesize 120
global ruta "C:\Users\Paul\Documents\Yape"                   // <- cambiar si es 
* ─── RUTAS (ajusta si tu estructura de carpetas es diferente) ────────────────
global datos   "data"
global tablas  "tablas"
global graficos "graficos"

* Crear carpetas si no existen
capture mkdir "$datos"
capture mkdir "$tablas"
capture mkdir "$graficos"


* ─── LOG ─────────────────────────────────────────────────────────────────────
capture log close
log using "$tablas/log_analisis_TAM.log", text replace

display _newline(2) "============================================================"
display "   ANÁLISIS TAM — YAPE/PLIN   |   Keila Bocanegra   |   2026"
display "============================================================" _newline


/*==============================================================================
  SECCIÓN 1: IMPORTAR Y PREPARAR DATOS
==============================================================================*/
cd "C:\Users\Paul\Documents\Yape"
display _newline ">>> SECCIÓN 1: IMPORTAR DATOS"

import delimited "raw_data4", ///
    delimiter(";") varnames(1) encoding(UTF-8) clear

* Verificar carga
describe
codebook, compact

* ─── Recodificar Likert a numérico ───────────────────────────────────────────
* Escala: 1=Totalmente en desacuerdo … 5=Totalmente de acuerdo

local escala_vars iva1 iva2 iva3 up1 up2 up3 fu1 fu2 fu3 ///
                  seg1 seg2 seg3 conf1 conf2 conf3 ///
                  act1 act2 act3 int1 int2 int3

foreach v of local escala_vars {
    * Si ya están en texto, recodificamos
    capture confirm string variable `v'
    if _rc == 0 {
        gen `v'_n = .
        replace `v'_n = 1 if `v' == "Totalmente en desacuerdo"
        replace `v'_n = 2 if `v' == "En desacuerdo"
        replace `v'_n = 3 if `v' == "Neutral"
        replace `v'_n = 4 if `v' == "De acuerdo"
        replace `v'_n = 5 if `v' == "Totalmente de acuerdo"
        label variable `v'_n "`v' (1-5)"
    }
    else {
        * Ya es numérica, solo renombramos para consistencia
        clonevar `v'_n = `v'
        label variable `v'_n "`v' (1-5)"
    }
}

* ─── Recodificar demográficas ─────────────────────────────────────────────────
* Edad
encode edad_rango, gen(edad_n)
label variable edad_n "Rango de edad"

* Sexo
encode sexo, gen(sexo_n)
label variable sexo_n "Sexo"

* Nivel educativo (ordinal)
gen niv_educ_n = .
replace niv_educ_n = 1 if niv_educ == "Secundaria"
replace niv_educ_n = 2 if niv_educ == "Técnico"
replace niv_educ_n = 3 if niv_educ == "Universitario"
replace niv_educ_n = 4 if niv_educ == "Posgrado"
label define educ_lbl 1 "Secundaria" 2 "Técnico" 3 "Universitario" 4 "Posgrado"
label values niv_educ_n educ_lbl
label variable niv_educ_n "Nivel educativo"

* Frecuencia uso apps (ordinal)
gen freq_apps_n = .
replace freq_apps_n = 1 if freq_apps == "Baja"
replace freq_apps_n = 2 if freq_apps == "Media"
replace freq_apps_n = 3 if freq_apps == "Alta"
label define freq_lbl 1 "Baja" 2 "Media" 3 "Alta"
label values freq_apps_n freq_lbl
label variable freq_apps_n "Frecuencia de uso de apps financieras (ordinal)"

* Frecuencia de transferencias (ordinal)
gen frec_transf_n = .
replace frec_transf_n = 1 if frec_transf == "Nunca"
replace frec_transf_n = 2 if frec_transf == "Rara vez"
replace frec_transf_n = 3 if frec_transf == "A veces"
replace frec_transf_n = 4 if frec_transf == "Casi siempre"
replace frec_transf_n = 5 if frec_transf == "Siempre"
label define frec_lbl 1 "Nunca" 2 "Rara vez" 3 "A veces" 4 "Casi siempre" 5 "Siempre"
label values frec_transf_n frec_lbl
label variable frec_transf_n "Frecuencia de transferencias"

* Variables binarias de conocimiento y uso
foreach v of varlist con_qr con_recarga con_pagoserv con_promo con_cashback con_transf {
    gen `v'_n = (`v' == "Si")
    label variable `v'_n "`v' (1=Sí)"
}
foreach v of varlist uso_qr uso_recarga uso_pagoserv uso_promo uso_cashback uso_transf {
    gen `v'_n = (`v' == "Utiliza")
    label variable `v'_n "`v' (1=Utiliza)"
}

* ─── Etiquetas para los ítems Likert ─────────────────────────────────────────
label variable iva1_n "IVA1: Uso Yape/Plin me genera valor adicional"
label variable iva2_n "IVA2: Las funciones me ofrecen beneficios tangibles"
label variable iva3_n "IVA3: Prefiero Yape/Plin por el valor que aporta"
label variable up1_n  "UP1: Yape/Plin mejora mi gestión financiera"
label variable up2_n  "UP2: Uso Yape/Plin aumenta mi productividad"
label variable up3_n  "UP3: Yape/Plin es útil para mis transacciones"
label variable fu1_n  "FU1: Aprender a usar Yape/Plin es fácil"
label variable fu2_n  "FU2: Yape/Plin es fácil de usar"
label variable fu3_n  "FU3: Interactuar con Yape/Plin no requiere esfuerzo"
label variable seg1_n "SEG1: Mis datos están seguros en Yape/Plin"
label variable seg2_n "SEG2: Las transacciones son seguras"
label variable seg3_n "SEG3: Confío en la protección ante fraudes"
label variable conf1_n "CONF1: Yape/Plin cumple lo que promete"
label variable conf2_n "CONF2: Confío en el funcionamiento del sistema"
label variable conf3_n "CONF3: Tengo confianza general en Yape/Plin"
label variable act1_n  "ACT1: Usar Yape/Plin es buena idea"
label variable act2_n  "ACT2: Tengo actitud positiva hacia su uso"
label variable act3_n  "ACT3: Me agrada usar Yape/Plin"
label variable int1_n  "INT1: Tengo intención de seguir usando Yape/Plin"
label variable int2_n  "INT2: Planeo usar Yape/Plin en el futuro"
label variable int3_n  "INT3: Recomendaría Yape/Plin a otros"


/*==============================================================================
  SECCIÓN 2: ESTADÍSTICAS DESCRIPTIVAS
==============================================================================*/

display _newline ">>> SECCIÓN 2: ESTADÍSTICAS DESCRIPTIVAS"

* Demografía
tab edad_rango
tab sexo
tab niv_educ
tab freq_apps
tab frec_transf

* Conocimiento y uso de funciones
display _newline "--- Conocimiento de funciones ---"
foreach v in con_qr_n con_recarga_n con_pagoserv_n con_promo_n con_cashback_n con_transf_n {
    quietly sum `v'
    display "`v': " %4.1f r(mean)*100 "% conoce"
}

display _newline "--- Uso de funciones ---"
foreach v in uso_qr_n uso_recarga_n uso_pagoserv_n uso_promo_n uso_cashback_n uso_transf_n {
    quietly sum `v'
    display "`v': " %4.1f r(mean)*100 "% utiliza"
}

* Ítems Likert
display _newline "--- Estadísticas de ítems Likert ---"
local todos_items iva1_n iva2_n iva3_n up1_n up2_n up3_n fu1_n fu2_n fu3_n ///
                  seg1_n seg2_n seg3_n conf1_n conf2_n conf3_n ///
                  act1_n act2_n act3_n int1_n int2_n int3_n
summarize `todos_items'


/*==============================================================================
  SECCIÓN 3: ÍNDICES DE CONSTRUCTO
  Se crean promedios simples de los 3 ítems por constructo.
  Se usan en las regresiones descriptivas (Sección 7).
  El SEM usa los ítems individuales directamente (Secciones 5-6).
==============================================================================*/

display _newline ">>> SECCIÓN 3: ÍNDICES DE CONSTRUCTO"

egen valor_anadido  = rowmean(iva1_n iva2_n iva3_n)
egen utilidad       = rowmean(up1_n  up2_n  up3_n)
egen facilidad_uso  = rowmean(fu1_n  fu2_n  fu3_n)
egen seguridad      = rowmean(seg1_n seg2_n seg3_n)
egen confianza      = rowmean(conf1_n conf2_n conf3_n)
egen actitud        = rowmean(act1_n  act2_n  act3_n)
egen intencion_uso  = rowmean(int1_n  int2_n  int3_n)

label variable valor_anadido "Índice: Uso del valor añadido (IVA)"
label variable utilidad      "Índice: Utilidad percibida (UP)"
label variable facilidad_uso "Índice: Facilidad de uso (FU)"
label variable seguridad     "Índice: Seguridad percibida (SEG)"
label variable confianza     "Índice: Confianza (CONF)"
label variable actitud       "Índice: Actitud hacia el uso (ACT)"
label variable intencion_uso "Índice: Intención de uso (INT)"

summarize valor_anadido utilidad facilidad_uso seguridad confianza actitud intencion_uso

* Correlación entre índices (referencia antes del SEM)
display _newline "--- Matriz de correlaciones entre constructos ---"
correlate valor_anadido utilidad facilidad_uso seguridad confianza actitud intencion_uso


/*==============================================================================
  SECCIÓN 4: CONFIABILIDAD (ALPHA DE CRONBACH)
==============================================================================*/

display _newline ">>> SECCIÓN 4: CONFIABILIDAD — ALPHA DE CRONBACH"
display "(Criterio: α ≥ 0.70 aceptable; α ≥ 0.80 bueno)"

alpha iva1_n iva2_n iva3_n,   label item
alpha up1_n  up2_n  up3_n,    label item
alpha fu1_n  fu2_n  fu3_n,    label item
alpha seg1_n seg2_n seg3_n,   label item
alpha conf1_n conf2_n conf3_n, label item
alpha act1_n act2_n act3_n,   label item
alpha int1_n int2_n int3_n,   label item


/*==============================================================================
  SECCIÓN 5: ANÁLISIS FACTORIAL CONFIRMATORIO (AFC)
  Modelo de medición: 7 factores latentes, 3 ítems cada uno.
  Verifica validez convergente y discriminante antes del SEM.
==============================================================================*/

display _newline ">>> SECCIÓN 5: ANÁLISIS FACTORIAL CONFIRMATORIO (AFC)"

sem ///
    (ValorAnadido  -> iva1_n iva2_n iva3_n)  ///
    (Utilidad      -> up1_n  up2_n  up3_n)   ///
    (FacilidadUso  -> fu1_n  fu2_n  fu3_n)   ///
    (Seguridad     -> seg1_n seg2_n seg3_n)  ///
    (Confianza     -> conf1_n conf2_n conf3_n) ///
    (Actitud       -> act1_n act2_n act3_n)  ///
    (IntencionUso  -> int1_n int2_n int3_n), ///
    method(mlmv) standardized difficult iterate(1000)

estimates store AFC_Medicion

display _newline "--- Índices de ajuste del AFC ---"
estat gof, stats(all)

display _newline "--- Bondad de ajuste por ecuación (cargas factoriales y R²) ---"
estat eqgof

display _newline "--- Matriz de covarianzas entre factores latentes ---"
estat framework

* Exportar AFC
esttab AFC_Medicion using "$tablas/tabla_AFC.rtf", ///
    replace                                         ///
    title("AFC — Modelo de medición TAM")           ///
    cells(b(fmt(3)) se(par fmt(3)) p(fmt(3)))       ///
    label

	/*==============================================================================
 SECCIÓN 5.1: AVE, CR Y VALIDEZ DISCRIMINANTE
==============================================================================*/

display _newline ">>> SECCIÓN 5.1: AVE, CR Y FORNELL-LARCKER"

*****************************************************
*** AVE Y CONFIABILIDAD COMPUESTA (CR)
*****************************************************

display _newline "Constructo        AVE        CR"


* Valor añadido
display "ValorAnadido   " ///
%6.3f ((0.8341613^2+0.8097540^2+0.8149907^2)/3) ///
"   " ///
%6.3f (((0.8341613+0.8097540+0.8149907)^2)/ ///
(((0.8341613+0.8097540+0.8149907)^2)+ ///
((1-0.8341613^2)+(1-0.8097540^2)+(1-0.8149907^2))))


* Utilidad
display "Utilidad       " ///
%6.3f ((0.8432470^2+0.8101044^2+0.8558035^2)/3) ///
"   " ///
%6.3f (((0.8432470+0.8101044+0.8558035)^2)/ ///
(((0.8432470+0.8101044+0.8558035)^2)+ ///
((1-0.8432470^2)+(1-0.8101044^2)+(1-0.8558035^2))))


* Facilidad
display "FacilidadUso   " ///
%6.3f ((0.8161755^2+0.8760952^2+0.8161044^2)/3) ///
"   " ///
%6.3f (((0.8161755+0.8760952+0.8161044)^2)/ ///
(((0.8161755+0.8760952+0.8161044)^2)+ ///
((1-0.8161755^2)+(1-0.8760952^2)+(1-0.8161044^2))))


* Seguridad
display "Seguridad      " ///
%6.3f ((0.7963698^2+0.8140808^2+0.8399756^2)/3) ///
"   " ///
%6.3f (((0.7963698+0.8140808+0.8399756)^2)/ ///
(((0.7963698+0.8140808+0.8399756)^2)+ ///
((1-0.7963698^2)+(1-0.8140808^2)+(1-0.8399756^2))))


* Confianza
display "Confianza      " ///
%6.3f ((0.8048523^2+0.8326429^2+0.8386517^2)/3) ///
"   " ///
%6.3f (((0.8048523+0.8326429+0.8386517)^2)/ ///
(((0.8048523+0.8326429+0.8386517)^2)+ ///
((1-0.8048523^2)+(1-0.8326429^2)+(1-0.8386517^2))))


* Actitud
display "Actitud        " ///
%6.3f ((0.7988779^2+0.8465949^2+0.8697558^2)/3) ///
"   " ///
%6.3f (((0.7988779+0.8465949+0.8697558)^2)/ ///
(((0.7988779+0.8465949+0.8697558)^2)+ ///
((1-0.7988779^2)+(1-0.8465949^2)+(1-0.8697558^2))))


* Intención
display "IntencionUso  " ///
%6.3f ((0.8334060^2+0.8451159^2+0.7963325^2)/3) ///
"   " ///
%6.3f (((0.8334060+0.8451159+0.7963325)^2)/ ///
(((0.8334060+0.8451159+0.7963325)^2)+ ///
((1-0.8334060^2)+(1-0.8451159^2)+(1-0.7963325^2))))

*======================================================
* Exportar AVE, CR y Alfa de Cronbach
*======================================================

putexcel set "$tablas/Validez.xlsx", replace

putexcel A1=("Constructo") ///
         B1=("AVE") ///
         C1=("CR")

putexcel A2=("Valor añadido")   B2=(0.672) C2=(0.860)
putexcel A3=("Utilidad")        B3=(0.700) C3=(0.875)
putexcel A4=("FacilidadUso")    B4=(0.700) C4=(0.875)
putexcel A5=("Seguridad")       B5=(0.667) C5=(0.858)
putexcel A6=("Confianza")       B6=(0.681) C6=(0.865)
putexcel A7=("Actitud")         B7=(0.704) C7=(0.877)
putexcel A8=("IntencionUso")    B8=(0.681) C8=(0.865)

display "Tabla exportada a Validez.xlsx"

/*==============================================================================
  SECCIÓN 6: MODELO DE ECUACIONES ESTRUCTURALES (SEM)
  Modelo estructural TAM con 7 hipótesis.
  Sin influencia_cultural (no medida en el cuestionario).
==============================================================================*/

display _newline ">>> SECCIÓN 6: MODELO SEM — TAM"
display _newline "Hipótesis:"
display "  H1: FacilidadUso  → Actitud"
display "  H2: Utilidad      → Actitud"
display "  H3: Utilidad      → IntencionUso"
display "  H4: Actitud       → IntencionUso"
display "  H5: Seguridad     → IntencionUso"
display "  H6: Confianza     → IntencionUso"
display "  H7: IntencionUso  → ValorAnadido"

sem ///
    (FacilidadUso  -> fu1_n  fu2_n  fu3_n)    ///
    (Utilidad      -> up1_n  up2_n  up3_n)    ///
    (Seguridad     -> seg1_n seg2_n seg3_n)   ///
    (Confianza     -> conf1_n conf2_n conf3_n) ///
    (Actitud       -> act1_n act2_n act3_n)   ///
    (IntencionUso  -> int1_n int2_n int3_n)   ///
    (ValorAnadido  -> iva1_n iva2_n iva3_n)   ///
    (Actitud       <- FacilidadUso Utilidad)           ///
    (IntencionUso  <- Actitud Utilidad Seguridad Confianza) ///
    (ValorAnadido  <- IntencionUso),                   ///
    method(mlmv) standardized difficult iterate(1000)

estimates store SEM_TAM

* ─── Índices de ajuste ────────────────────────────────────────────────────────
display _newline "--- ÍNDICES DE AJUSTE DEL SEM ---"
display "Criterios: CFI≥0.90 | TLI≥0.90 | RMSEA≤0.08 | SRMR≤0.08"
estat gof, stats(all)

* ─── Ajuste por ecuación (R² de cada variable) ───────────────────────────────
display _newline "--- AJUSTE POR ECUACIÓN ---"
estat eqgof

* ─── Efectos directos, indirectos y totales ───────────────────────────────────
*display _newline "--- EFECTOS DIRECTOS, INDIRECTOS Y TOTALES ---"
*estat teffects* (NO se usa este comando por que nuestro modelo no tiene efectos indirectos)

* ─── Índices de modificación (si ajuste fuera deficiente) ────────────────────
display _newline "--- ÍNDICES DE MODIFICACIÓN (referencia) ---"
estat mindices

* ─── Residuales ──────────────────────────────────────────────────────────────
display _newline "--- RESIDUALES DE COVARIANZA ---"
estat residuals

* ─── Exportar SEM ─────────────────────────────────────────────────────────────
esttab SEM_TAM using "$tablas/tabla_SEM.rtf", ///
    replace                                    ///
    title("SEM — Modelo TAM (estandarizado)")  ///
    cells(b(fmt(3)) se(par fmt(3)) p(fmt(3)))  ///
    label


/*==============================================================================
  SECCIÓN 7: PRUEBA DE HIPÓTESIS — REGRESIONES COMPLEMENTARIAS
  Análisis OLS sobre índices: complementa el SEM con interpretación sencilla.
  ADVERTENCIA: NO incluye influencia_cultural (no existe en el instrumento).
==============================================================================*/

display _newline ">>> SECCIÓN 7: REGRESIONES LINEALES — PRUEBA DE HIPÓTESIS"

* ── H1 y H2: FacilidadUso y Utilidad → Actitud ──────────────────────────────
display _newline "--- H1 (FacilidadUso → Actitud) y H2 (Utilidad → Actitud) ---"
regress actitud facilidad_uso utilidad, beta
estimates store reg_H1H2

test facilidad_uso    // H1
test utilidad         // H2

* ── H3-H6: Predictores → IntencionUso ───────────────────────────────────────
display _newline "--- H3 (Utilidad), H4 (Actitud), H5 (Seguridad), H6 (Confianza) → IntencionUso ---"
regress intencion_uso utilidad actitud seguridad confianza, beta
estimates store reg_H3H6

test utilidad      // H3
test actitud       // H4
test seguridad     // H5
test confianza     // H6

* ── H7: IntencionUso → ValorAnadido ─────────────────────────────────────────
display _newline "--- H7 (IntencionUso → ValorAnadido) ---"
regress valor_anadido intencion_uso, beta
estimates store reg_H7

test intencion_uso // H7

* ─── Tabla combinada de regresiones ─────────────────────────────────────────
esttab reg_H1H2 reg_H3H6 reg_H7 using "$tablas/tabla_regresiones.rtf", ///
    replace beta se                                                       ///
    star(* 0.05 ** 0.01 *** 0.001)                                       ///
    title("Tabla: Regresiones lineales — Prueba de hipótesis H1-H7")     ///
    mtitles("Actitud (H1-H2)" "IntenciónUso (H3-H6)" "ValorAnadido (H7)") ///
    label r2 ar2                                                          ///
    addnotes("Coeficientes Beta estandarizados. * p<0.05 ** p<0.01 *** p<0.001" ///
             "Nota: influencia_cultural eliminada (no medida en el instrumento)")


/*==============================================================================
  SECCIÓN 8: RESUMEN DE HIPÓTESIS
==============================================================================*/

display _newline "============================================================"
display "RESUMEN DE HIPÓTESIS — SEM ESTANDARIZADO"
display "============================================================"
display " H  | Relación                          | Decisión"
display "----+-----------------------------------+----------"
display " H1 | FacilidadUso  → Actitud           | (ver β y p arriba)"
display " H2 | Utilidad      → Actitud           | (ver β y p arriba)"
display " H3 | Utilidad      → IntencionUso      | (ver β y p arriba)"
display " H4 | Actitud       → IntencionUso      | (ver β y p arriba)"
display " H5 | Seguridad     → IntencionUso      | (ver β y p arriba)"
display " H6 | Confianza     → IntencionUso      | (ver β y p arriba)"
display " H7 | IntencionUso  → ValorAnadido      | (ver β y p arriba)"
display "============================================================"
display "Criterio de decisión: p < 0.05 → Hipótesis soportada"


/*==============================================================================
  SECCIÓN 9: ANÁLISIS POR SUBGRUPOS
==============================================================================*/

display _newline ">>> SECCIÓN 9: ANÁLISIS POR SUBGRUPOS"

* ── 9.1 Por rango de edad (ANOVA) ────────────────────────────────────────────
display _newline "--- Intención de uso por edad ---"
oneway intencion_uso edad_n, tabulate bonferroni

display _newline "--- Valor añadido por edad ---"
oneway valor_anadido edad_n, tabulate bonferroni

graph bar (mean) intencion_uso valor_anadido, over(edad_n) ///
    title("Intención de uso y valor añadido por rango de edad") ///
    legend(label(1 "Intención de uso") label(2 "Valor añadido")) ///
    blabel(bar, format(%4.2f)) ylabel(1(0.5)5) ytitle("Media (1-5)")
graph export "$graficos/g1_edad_int_val.png", replace width(1400)

* ── 9.2 Por sexo (prueba t) ──────────────────────────────────────────────────
display _newline "--- Intención de uso por sexo ---"
ttest intencion_uso, by(sexo_n)

display _newline "--- Valor añadido por sexo ---"
ttest valor_anadido, by(sexo_n)

graph bar (mean) intencion_uso valor_anadido, over(sexo_n) ///
    title("Intención de uso y valor añadido por sexo") ///
    legend(label(1 "Intención de uso") label(2 "Valor añadido")) ///
    blabel(bar, format(%4.2f)) ylabel(1(0.5)5) ytitle("Media (1-5)")
graph export "$graficos/g2_sexo_int_val.png", replace width(1400)

* ── 9.3 Por nivel educativo (ANOVA) ─────────────────────────────────────────
display _newline "--- Constructos por nivel educativo ---"
oneway utilidad    niv_educ_n, tabulate
oneway seguridad   niv_educ_n, tabulate
oneway confianza   niv_educ_n, tabulate
oneway intencion_uso niv_educ_n, tabulate

graph bar (mean) utilidad seguridad confianza, over(niv_educ_n) ///
    title("Utilidad, seguridad y confianza por nivel educativo") ///
    legend(label(1 "Utilidad") label(2 "Seguridad") label(3 "Confianza")) ///
    blabel(bar, format(%4.2f)) ylabel(1(0.5)5) ytitle("Media (1-5)")
graph export "$graficos/g3_educ_constructos.png", replace width(1400)

* ── 9.4 Por frecuencia de uso de apps ───────────────────────────────────────
display _newline "--- Valor añadido por frecuencia de uso de apps ---"
oneway valor_anadido freq_apps_n, tabulate

graph bar (mean) valor_anadido intencion_uso, over(freq_apps_n) ///
    title("Valor añadido e intención de uso según frecuencia de apps") ///
    legend(label(1 "Valor añadido") label(2 "Intención de uso")) ///
    blabel(bar, format(%4.2f)) ylabel(1(0.5)5) ytitle("Media (1-5)")
graph export "$graficos/g4_freqapps_val_int.png", replace width(1400)


/*==============================================================================
  SECCIÓN 10: GRÁFICOS DE DISPERSIÓN — RELACIONES CLAVE
==============================================================================*/

display _newline ">>> SECCIÓN 10: GRÁFICOS DE DISPERSIÓN"

* H3: Utilidad → IntencionUso
twoway (scatter intencion_uso utilidad, mcolor(%30) msize(small)) ///
       (lfit    intencion_uso utilidad, lcolor(navy) lwidth(medium)), ///
    title("H3: Utilidad percibida → Intención de uso") ///
    xtitle("Utilidad percibida (1-5)") ytitle("Intención de uso (1-5)") ///
    legend(off)
graph export "$graficos/g5_util_int.png", replace width(1200)

* H4: Actitud → IntencionUso
twoway (scatter intencion_uso actitud, mcolor(%30) msize(small)) ///
       (lfit    intencion_uso actitud, lcolor(maroon) lwidth(medium)), ///
    title("H4: Actitud → Intención de uso") ///
    xtitle("Actitud hacia el uso (1-5)") ytitle("Intención de uso (1-5)") ///
    legend(off)
graph export "$graficos/g6_act_int.png", replace width(1200)

* H5: Seguridad → IntencionUso
twoway (scatter intencion_uso seguridad, mcolor(%30) msize(small)) ///
       (lfit    intencion_uso seguridad, lcolor(forest_green) lwidth(medium)), ///
    title("H5: Seguridad percibida → Intención de uso") ///
    xtitle("Seguridad percibida (1-5)") ytitle("Intención de uso (1-5)") ///
    legend(off)
graph export "$graficos/g7_seg_int.png", replace width(1200)

* H6: Confianza → IntencionUso
twoway (scatter intencion_uso confianza, mcolor(%30) msize(small)) ///
       (lfit    intencion_uso confianza, lcolor(purple) lwidth(medium)), ///
    title("H6: Confianza → Intención de uso") ///
    xtitle("Confianza (1-5)") ytitle("Intención de uso (1-5)") ///
    legend(off)
graph export "$graficos/g8_conf_int.png", replace width(1200)

* H7: IntencionUso → ValorAnadido
twoway (scatter valor_anadido intencion_uso, mcolor(%30) msize(small)) ///
       (lfit    valor_anadido intencion_uso, lcolor(orange) lwidth(medium)), ///
    title("H7: Intención de uso → Valor añadido") ///
    xtitle("Intención de uso (1-5)") ytitle("Valor añadido (1-5)") ///
    legend(off)
graph export "$graficos/g9_int_val.png", replace width(1200)


/*==============================================================================
  SECCIÓN 11: ESTADÍSTICAS RESUMEN PARA EL CAPÍTULO DE RESULTADOS
==============================================================================*/

display _newline ">>> SECCIÓN 11: CIFRAS CLAVE PARA EL TEXTO"

quietly count
local n_total = r(N)
display "N total: `n_total'"

* % frecuencia Alta o Media
count if freq_apps_n >= 2
display "Frecuencia Alta o Media: " %4.1f (r(N)/`n_total')*100 "%"

* % que percibe utilidad (de acuerdo en los 3 ítems)
egen up_acuerdo = rowmin(up1_n up2_n up3_n)
count if up_acuerdo >= 4
display "Percibe utilidad alta (≥4 en los 3 ítems UP): " %4.1f (r(N)/`n_total')*100 "%"
drop up_acuerdo

* % con intención de continuar (int1 ≥ 4)
count if int1_n >= 4
display "Intención de continuar usando (int1 ≥ 4): " %4.1f (r(N)/`n_total')*100 "%"

* % que recomendaría (int3 ≥ 4)
count if int3_n >= 4
display "Recomendaría el servicio (int3 ≥ 4): " %4.1f (r(N)/`n_total')*100 "%"

* % que confía en el sistema (conf1 ≥ 4)
count if conf1_n >= 4
display "Confía en el sistema (conf1 ≥ 4): " %4.1f (r(N)/`n_total')*100 "%"

* Uso de funciones
display _newline "Uso de funciones específicas:"
foreach v in uso_qr_n uso_recarga_n uso_pagoserv_n uso_promo_n uso_cashback_n uso_transf_n {
    quietly sum `v'
    display "  `v': " %4.1f r(mean)*100 "%"
}


/*==============================================================================
  SECCIÓN 12: GUARDAR BASE FINAL
==============================================================================*/

display _newline ">>> SECCIÓN 12: GUARDAR BASE FINAL"

save "$datos/base_final_TAM.dta", replace
export delimited "$datos/base_final_TAM.csv", replace

display _newline "============================================================"
display "ANÁLISIS COMPLETO."
display "Tablas en: $tablas"
display "Gráficos en: $graficos"
display "Base final en: $datos/base_final_TAM.dta"
display "============================================================"

log close

/*==============================================================================
  FIN DEL DO-FILE
==============================================================================*/
