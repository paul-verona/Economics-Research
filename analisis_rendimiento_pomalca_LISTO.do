/*******************************************************************************
1. IMPORTAR ENCUESTA DE PADRES
*****************************************************************************
clear all
set more off

global root "C:\Users\Paul\Documents\tesis luis"
global output "$root\resultados"

capture mkdir "$output"

import excel using ///
"$root\ENCUESTA PARA PADRES REPORTE FINAL.xlsx", ///
clear allstring


rename A codigo
rename B nombre
rename C nota_mat_str
rename D nota_com_str
rename E institucion
rename F seccion

rename G p1
rename H p2
rename I p3
rename J p4
rename K p5
rename L p6
rename M p7
rename N p8
rename O p9

rename P p10
rename Q p11
rename R p12
rename S p13
rename T p14
rename U p15
rename V p16
rename W p17
rename X p18


drop in 1


destring nota_mat_str, gen(nota_mat) force
destring nota_com_str, gen(nota_com) force

drop nota_mat_str nota_com_str


gen rendimiento=(nota_mat+nota_com)/2


gen cod_ie=substr(codigo,1,3)


save "$output\base_encuesta.dta", replace

/*******************************************************************************
2. IMPORTAR GESTIÓN E INFRAESTRUCTURA
*******************************************************************************/

import excel using ///
"$root\Gestión e infraestructura.xlsx", ///
clear allstring


rename A cod_ie
rename B ie_nombre
rename C tipo_gestion

rename D g1_obs_clases
rename E g2_retroalim
rename F g3_rev_planif
rename G g4_reuniones
rename H g5_doc_planif
rename I g6_supervisa_mat
rename J g7_recursos_mat

rename K i1_aulas
rename L i2_sshh
rename M i3_local
rename N i4_mat_basicos
rename O i5_disp_mat
rename P i6_tecnologia
rename Q i7_servicios
rename R i8_mantenimiento
rename S i9_limpieza


drop in 1


duplicates report cod_ie

duplicates list cod_ie


* ELIMINAR DUPLICADOS

duplicates drop cod_ie, force


save "$output\base_gestion.dta", replace

/*******************************************************************************
3. MERGE
*******************************************************************************/

use "$output\base_encuesta.dta", clear


merge m:1 cod_ie using ///
"$output\base_gestion.dta"



tab _merge


keep if _merge==3


drop _merge


save "$output\base_final.dta", replace

/*******************************************************************************
4. RECODIFICACIÓN Y CONSTRUCCIÓN DE ÍNDICES
*******************************************************************************/

use "$output\base_final.dta", clear
*****Sociecoonimco***
gen p1_n=.
replace p1_n=1 if regexm(p1,"[Ss]in estudio")
replace p1_n=2 if regexm(p1,"[Pp]rimaria")
replace p1_n=3 if regexm(p1,"[Ss]ecundaria")
replace p1_n=4 if regexm(p1,"[Tt]ecn")
replace p1_n=5 if regexm(p1,"[Uu]nivers")


gen p2_n=.
replace p2_n=1 if regexm(p2,"[Ss]in estudio")
replace p2_n=2 if regexm(p2,"[Pp]rimaria")
replace p2_n=3 if regexm(p2,"[Ss]ecundaria")
replace p2_n=4 if regexm(p2,"[Tt]ecn")
replace p2_n=5 if regexm(p2,"[Uu]nivers")


gen p3_n=.
replace p3_n=1 if regexm(p3,"[Nn]unca")
replace p3_n=2 if regexm(p3,"[Aa] veces")
replace p3_n=3 if regexm(p3,"[Cc]asi siempre")
replace p3_n=4 if regexm(p3,"[Ss]iempre") & !regexm(p3,"[Cc]asi")


gen p4_n=.
replace p4_n=1 if regexm(p4,"[Nn]inguna")
replace p4_n=2 if regexm(p4,"[Uu]na")
replace p4_n=3 if regexm(p4,"[Dd]os")
replace p4_n=4 if regexm(p4,"[Tt]res")


gen p5_n=.
replace p5_n=1 if regexm(p5,"[Nn]inguno")
replace p5_n=2 if regexm(p5,"[Uu]no")
replace p5_n=3 if regexm(p5,"[Aa]mbos")


gen p6_n=.
replace p6_n=1 if regexm(p6,"[Nn]o tiene")
replace p6_n=2 if regexm(p6,"[Ii]mprovis")
replace p6_n=3 if regexm(p6,"[Cc]ompart")
replace p6_n=4 if regexm(p6,"[Aa]decuado")


gen p7_n=.
replace p7_n=1 if regexm(p7,"[Nn]o tiene")
replace p7_n=2 if regexm(p7,"[Cc]uent")
replace p7_n=3 if regexm(p7,"[Ee]scolar")
replace p7_n=4 if regexm(p7,"[Vv]ariedad")


gen p8_n=.
replace p8_n=1 if regexm(p8,"[Nn]o tiene")
replace p8_n=2 if regexm(p8,"[Dd]atos")
replace p8_n=3 if regexm(p8,"[Cc]ompart")
replace p8_n=4 if regexm(p8,"[Pp]ropio")


gen p9_n=.
replace p9_n=1 if regexm(p9,"[Nn]o tiene")
replace p9_n=2 if regexm(p9,"[Oo]tra")
replace p9_n=3 if regexm(p9,"[Cc]ompart")
replace p9_n=4 if regexm(p9,"[Pp]ropio")


***acompñamiento****

local j=10

foreach v in p10 p11 p12 p13 p14 p15 p16 p17 p18{

gen p`j'_n=.

replace p`j'_n=1 if regexm(`v',"[Nn]unca")
replace p`j'_n=2 if regexm(`v',"[Aa] veces")
replace p`j'_n=3 if regexm(`v',"[Cc]asi siempre")
replace p`j'_n=4 if regexm(`v',"[Ss]iempre") & !regexm(`v',"[Cc]asi")

local ++j
}


*****gestion******

foreach v in g1_obs_clases g2_retroalim g3_rev_planif ///
g4_reuniones g5_doc_planif g6_supervisa_mat{

gen `v'_n=.

replace `v'_n=1 if `v'=="Anual"
replace `v'_n=2 if `v'=="Trimestral"
replace `v'_n=3 if `v'=="Bimestral"
replace `v'_n=4 if `v'=="Mensual"

}



gen g7_recursos_mat_n=.

replace g7_recursos_mat_n=1 if g7_recursos_mat=="Nunca"

replace g7_recursos_mat_n=2 if g7_recursos_mat=="Rara vez"

replace g7_recursos_mat_n=3 if g7_recursos_mat=="A veces"

replace g7_recursos_mat_n=4 if g7_recursos_mat=="Casi siempre"


*****ingraestrutrua****

foreach v in i1_aulas i2_sshh i3_local{

gen `v'_n=.

replace `v'_n=1 if `v'=="Deficiente"
replace `v'_n=2 if `v'=="Regular"
replace `v'_n=3 if `v'=="Buena"
replace `v'_n=4 if `v'=="Muy buena"

}



foreach v in i4_mat_basicos i5_disp_mat i6_tecnologia{

gen `v'_n=.

replace `v'_n=1 if `v'=="Muy limitada"
replace `v'_n=2 if `v'=="Limitada"
replace `v'_n=3 if `v'=="Adecuada"
replace `v'_n=4 if `v'=="Suficiente"

}



foreach v in i7_servicios i8_mantenimiento i9_limpieza{

gen `v'_n=.

replace `v'_n=1 if `v'=="Deficiente"
replace `v'_n=2 if `v'=="Regular"
replace `v'_n=3 if `v'=="Bueno"
replace `v'_n=4 if `v'=="Muy bueno"

}


*****estandarizacion*****

gen p1_s=(p1_n-1)/4
gen p2_s=(p2_n-1)/4

gen p3_s=(p3_n-1)/3
gen p4_s=(p4_n-1)/3
gen p5_s=(p5_n-1)/2
gen p6_s=(p6_n-1)/3
gen p7_s=(p7_n-1)/3
gen p8_s=(p8_n-1)/3
gen p9_s=(p9_n-1)/3


foreach i of numlist 10/18{

gen p`i'_s=(p`i'_n-1)/3

}


gen g1_s=(g1_obs_clases_n-1)/3
gen g2_s=(g2_retroalim_n-1)/3
gen g3_s=(g3_rev_planif_n-1)/3
gen g4_s=(g4_reuniones_n-1)/3
gen g5_s=(g5_doc_planif_n-1)/3
gen g6_s=(g6_supervisa_mat_n-1)/3
gen g7_s=(g7_recursos_mat_n-1)/3


gen i1_s=(i1_aulas_n-1)/3
gen i2_s=(i2_sshh_n-1)/3
gen i3_s=(i3_local_n-1)/3
gen i4_s=(i4_mat_basicos_n-1)/3
gen i5_s=(i5_disp_mat_n-1)/3
gen i6_s=(i6_tecnologia_n-1)/3
gen i7_s=(i7_servicios_n-1)/3
gen i8_s=(i8_mantenimiento_n-1)/3
gen i9_s=(i9_limpieza_n-1)/3


****indioces****

egen FS=rowmean(p1_s p2_s p3_s p4_s p5_s p6_s p7_s p8_s p9_s)

egen AF=rowmean(p10_s p11_s p12_s p13_s p14_s p15_s p16_s p17_s p18_s)

egen AF_apoyo=rowmean(p10_s p11_s p12_s)

egen AF_supervision=rowmean(p13_s p14_s p15_s p16_s)

egen AF_motivacion=rowmean(p17_s p18_s)


egen GI=rowmean(g1_s g2_s g3_s g4_s g5_s g6_s g7_s)

egen INF=rowmean(i1_s i2_s i3_s i4_s i5_s i6_s i7_s i8_s i9_s)



label variable FS "Factores Socioeconómicos"

label variable AF "Acompañamiento Familiar"

label variable AF_apoyo "Apoyo académico"

label variable AF_supervision "Supervisión educativa"

label variable AF_motivacion "Motivación y refuerzo"

label variable GI "Gestión Institucional"

label variable INF "Infraestructura Institucional"


save "$output\base_total.dta", replace

/*******************************************************************************
5. CONSISTENCIA INTERNA – ALFA DE CRONBACH
*******************************************************************************/

di ""
di "========================================================="
di "        ALFA DE CRONBACH"
di "========================================================="



*******************************************************
* 5.1 FACTORES SOCIOECONÓMICOS
*******************************************************

di ""
di "Factores Socioeconómicos"

alpha ///
p1_n p2_n p3_n ///
p4_n p5_n p6_n ///
p7_n p8_n p9_n, ///
item std




*******************************************************
* 5.2 ACOMPAÑAMIENTO FAMILIAR
*******************************************************

di ""
di "Acompañamiento Familiar"

alpha ///
p10_n p11_n p12_n ///
p13_n p14_n p15_n ///
p16_n p17_n p18_n, ///
item std




*******************************************************
* 5.3 SUBDIMENSIONES DE AF
*******************************************************

di ""
di "Apoyo Académico"

alpha ///
p10_n p11_n p12_n, ///
item std



di ""
di "Supervisión Educativa"

alpha ///
p13_n p14_n ///
p15_n p16_n, ///
item std



di ""
di "Motivación y Refuerzo"

alpha ///
p17_n p18_n, ///
item std




*******************************************************
* 5.4 GESTIÓN INSTITUCIONAL
*******************************************************

di ""
di "Gestión Institucional"

di "Advertencia:"
di "El alfa se calcula con solo 10 instituciones."
di "La interpretación debe hacerse con cautela."


preserve

collapse (mean) ///
g1_obs_clases_n ///
g2_retroalim_n ///
g3_rev_planif_n ///
g4_reuniones_n ///
g5_doc_planif_n ///
g6_supervisa_mat_n ///
g7_recursos_mat_n, by(cod_ie)


alpha ///
g1_obs_clases_n ///
g2_retroalim_n ///
g3_rev_planif_n ///
g4_reuniones_n ///
g5_doc_planif_n ///
g6_supervisa_mat_n ///
g7_recursos_mat_n, ///
item std


restore




*******************************************************
* 5.5 INFRAESTRUCTURA
*******************************************************

di ""
di "Infraestructura"

preserve


collapse (mean) ///
i1_aulas_n ///
i2_sshh_n ///
i3_local_n ///
i4_mat_basicos_n ///
i5_disp_mat_n ///
i6_tecnologia_n ///
i7_servicios_n ///
i8_mantenimiento_n ///
i9_limpieza_n, by(cod_ie)



alpha ///
i1_aulas_n ///
i2_sshh_n ///
i3_local_n ///
i4_mat_basicos_n ///
i5_disp_mat_n ///
i6_tecnologia_n ///
i7_servicios_n ///
i8_mantenimiento_n ///
i9_limpieza_n, ///
item std


restore




*******************************************************
* 5.6 RESUMEN DE INTERPRETACIÓN
*******************************************************

di ""
di "Interpretación sugerida"

di "α ≥ 0.90 : Excelente"
di "0.80 ≤ α < 0.90 : Bueno"
di "0.70 ≤ α < 0.80 : Aceptable"
di "0.60 ≤ α < 0.70 : Cuestionable"
di "0.50 ≤ α < 0.60 : Pobre"
di "α < 0.50 : No aceptable"

/*******************************************************************************
6. ESTADÍSTICAS DESCRIPTIVAS
*******************************************************************************/

di ""
di "======================================================="
di "ESTADÍSTICAS DESCRIPTIVAS"
di "======================================================="


*******************************************************
* Estadísticas generales
*******************************************************

summarize ///
rendimiento ///
nota_mat ///
nota_com ///
FS ///
AF ///
GI ///
INF, detail



*******************************************************
* Tabla descriptiva
*******************************************************

tabstat ///
rendimiento ///
nota_mat ///
nota_com ///
FS ///
AF ///
GI ///
INF, ///
statistics( ///
n ///
mean ///
sd ///
min ///
max) ///
columns(statistics)



*******************************************************
* Matriz de correlaciones
*******************************************************

pwcorr ///
rendimiento ///
FS ///
AF ///
GI ///
INF, ///
sig star(.05)



*******************************************************
* Histogramas
*******************************************************

hist rendimiento, normal percent
graph export "$output\hist_rendimiento.png", replace


hist FS, normal percent
graph export "$output\hist_FS.png", replace


hist AF, normal percent
graph export "$output\hist_AF.png", replace


hist GI, normal percent
graph export "$output\hist_GI.png", replace


hist INF, normal percent
graph export "$output\hist_INF.png", replace




*******************************************************
* Boxplots
*******************************************************

graph box rendimiento

graph export ///
"$output\box_rendimiento.png", replace




graph box FS AF GI INF

graph export ///
"$output\box_indices.png", replace




*******************************************************
* Scatterplots
*******************************************************

foreach v in FS AF GI INF{


twoway ///
(scatter rendimiento `v') ///
(lfit rendimiento `v'), ///
name(g`v', replace)


graph export ///
"$output\scatter_`v'.png", replace


}

/*******************************************************************************
7. MODELOS DE REGRESIÓN
*******************************************************************************/

di ""
di "======================================================="
di "MODELOS DE REGRESIÓN"
di "======================================================="



*******************************************************
* Modelo 1
*******************************************************

reg rendimiento ///
FS ///
AF ///
GI ///
INF


estimates store M1




*******************************************************
* Modelo 2
*******************************************************

reg rendimiento ///
FS ///
AF ///
GI ///
INF, ///
vce(robust)


estimates store M2




*******************************************************
* Modelo 3
*******************************************************

reg rendimiento ///
FS ///
AF ///
GI ///
INF, ///
vce(cluster cod_ie)


estimates store M3




*******************************************************
* Comparación de modelos
*******************************************************

estimates table ///
M1 M2 M3, ///
b(%9.3f) ///
se ///
stats(N r2)



*******************************************************
* Coeficientes estandarizados
*******************************************************

reg rendimiento ///
FS ///
AF ///
GI ///
INF, beta




*******************************************************
* Predicciones
*******************************************************

predict yhat


predict resid, residuals


*******************************************************
* Guardar residuos
*******************************************************

save "$output\base_total.dta", replace


/*******************************************************************************
8. VALIDACIÓN DEL MODELO
*******************************************************************************/

di ""
di "======================================================="
di "VALIDACIÓN DEL MODELO"
di "======================================================="


*-------------------------------------------------------
* Modelo base
*-------------------------------------------------------

reg rendimiento FS AF GI INF


capture drop yhat
capture drop ehat
capture drop cook
capture drop lev


predict yhat
predict ehat, resid
predict cook, cooksd
predict lev, leverage



*-------------------------------------------------------
* Multicolinealidad
*-------------------------------------------------------

di ""
di "Multicolinealidad"

estat vif




*-------------------------------------------------------
* Homocedasticidad
*-------------------------------------------------------

di ""
di "Breusch-Pagan"

estat hettest


di ""
di "White"

estat imtest, white




*-------------------------------------------------------
* Normalidad
*-------------------------------------------------------

di ""
di "Shapiro-Wilk"

swilk ehat


di ""
di "Jarque-Bera"

sktest ehat




*-------------------------------------------------------
* RESET
*-------------------------------------------------------

di ""
di "RESET"

estat ovtest




*-------------------------------------------------------
* Errores robustos
*-------------------------------------------------------

reg rendimiento ///
FS AF GI INF, ///
vce(robust)

estimates store robust




*-------------------------------------------------------
* Observaciones influyentes
*-------------------------------------------------------

count

local umbral=4/r(N)


list codigo cod_ie rendimiento cook ///
if cook>`umbral', noobs




*-------------------------------------------------------
* Gráficos diagnósticos
*-------------------------------------------------------

twoway ///
(scatter ehat yhat) ///
(lowess ehat yhat), ///
yline(0) ///
title("Residuos vs Ajustados")


graph export ///
"$output\residuos_ajustados.png", ///
replace




qnorm ehat

graph export ///
"$output\qqplot.png", ///
replace




histogram ehat, normal

graph export ///
"$output\hist_residuos.png", ///
replace




foreach x in FS AF GI INF{


twoway ///
(scatter rendimiento `x') ///
(lfit rendimiento `x'), ///
title("Rendimiento vs `x'")


graph export ///
"$output\scatter_`x'.png", ///
replace


}

/*******************************************************************************
9. EXPORTACIÓN DE RESULTADOS
*******************************************************************************/


order codigo ///
nombre ///
institucion ///
seccion ///
cod_ie ///
rendimiento ///
nota_mat ///
nota_com ///
FS ///
AF ///
GI ///
INF



sort cod_ie codigo




label data ///
"Base final Pomalca 2026"




save ///
"$output\base_final_pomalca2026.dta", ///
replace




export excel using ///
"$output\base_final_pomalca2026.xlsx", ///
firstrow(variables) ///
replace




di ""
di "===================================================="

di "ANÁLISIS FINALIZADO"

di "===================================================="

di ""

di "Archivos generados"

di ""

di "base_final_pomalca2026.dta"

di "base_final_pomalca2026.xlsx"

di "residuos_ajustados.png"

di "qqplot.png"

di "hist_residuos.png"

di "scatter_FS.png"

di "scatter_AF.png"

di "scatter_GI.png"

di "scatter_INF.png"

di ""

di "===================================================="


capture log close
