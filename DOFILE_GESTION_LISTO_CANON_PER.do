*======================================================================*
* TEMA: GESTIÓN MUNICIPAL Y EFECTOS REDISTRIBUTIVOS DEL CANON MINERO
* Provincias mineras peruanas, 2015-2024
*
* MODELO PRINCIPAL:
*   gini = f(gini_l1, cxg, servicios, covid)
*   donde cxg = ln(canon) x gestion  (interacción)
*======================================================================*

clear all
set more off
cd "C:\Users\Paul\Documents\Mi tesis\modelo ods"

*======================================================================*
* 1. IMPORTAR Y PREPARAR BASE DE DATOS
*======================================================================*
import excel using "datos completos.xlsx", ///
    sheet("Hoja1") firstrow clear
drop L M N
rename Año anio
rename provincia prov

encode prov, gen(id_prov)
xtset id_prov anio

* Logaritmo del canon
gen ln_canon = ln(canon)
label variable ln_canon "Logaritmo del canon minero"
rename ln_canon lcanon_per
gen ldensidad = ln(densidad)
*****rezago canon_per****
gen ln_canon_per_l1 = L.lcanon_per
gen gestion_l1 = L.gestion
* Variable de interacción: gestión municipal x canon (en logs)
gen cxg = L.lcanon_per * gestion
label variable cxg "Interacción Ln(Canon) x Gestión municipal"

* Rezago de la variable dependiente
gen gini_l1 = L.gini
label variable gini_l1 "Índice de Gini rezagado (t-1)"

label variable gini      "Índice de Gini"
label variable canon     "Canon minero (transferencia, soles)"
label variable gestion   "Índice de gestión municipal"
label variable servicios "Cobertura de servicios básicos"
label variable covid     "Dummy COVID (2020-2021)"
*======================================================================*
* 2. ANÁLISIS ESTADÍSTICO DESCRIPTIVO DE CADA VARIABLE
*======================================================================*
summarize gini canon lcanon_per gestion cxg servicios ldensidad covid zona, detail

* Estadísticos por panel (between / within / overall)
xtsum gini lcanon_per gestion cxg servicios densidad covid zona

* Tabla descriptiva exportada a Excel
preserve

    matrix M = J(9,5,.)

    local vars gini canon lcanon_per gestion cxg servicios covid ldensidad zona

    local r = 1
    foreach v of local vars {

        quietly summarize `v'

        matrix M[`r',1] = r(N)
        matrix M[`r',2] = r(mean)
        matrix M[`r',3] = r(sd)
        matrix M[`r',4] = r(min)
        matrix M[`r',5] = r(max)

        local r = `r' + 1
    }

    matrix rownames M = gini canon lcanon_pe gestion cxg servicios covid ldensidad zona
    matrix colnames M = N Media DesvEst Min Max

    matrix list M

    putexcel set "Resultados_Descriptivos.xlsx", replace
    putexcel A1 = matrix(M), names

restore

* Correlaciones entre variables clave
correlate gini gini_l1 ln_canon_per_l1 gestion cxg servicios covid ldensidad zona

*--------------------------------------------------------------------
* MATRIZ DE CORRELACIONES
*--------------------------------------------------------------------

preserve

quietly correlate ///
    gini ///
    gini_l1 ///
    lcanon_per ///
    gestion ///
    cxg ///
    servicios ///
    covid ldensidad zona

matrix C = r(C)

putexcel set "Matriz_Correlaciones.xlsx", replace
putexcel A1 = matrix(C), names

display "Matriz de correlaciones exportada correctamente."

restore
*======================================================================*
* 3. GENERAR LA MUESTRA DEL MODELO (sin missing por rezago)
*======================================================================*
drop if missing(gini_l1)
drop if missing(ln_canon_per_l1)
drop if missing(cxg)
drop if missing(gestion_l1)

*======================================================================*
* 4. MODELO PRINCIPAL: POOLED OLS DINÁMICO CON INTERACCIÓN
*======================================================================*
reg gini gini_l1 ln_canon_per_l1 cxg gestion servicios covid ldensidad zona, vce(cluster id_prov)
estimates store M_PRINCIPAL

* Guardar resultados detallados
matrix b  = e(b)
matrix se = e(V)

*======================================================================*
* 5. PRUEBAS DE VALIDEZ DEL MODELO
*======================================================================*

* --- 5.1 Multicolinealidad (VIF) ---
quietly reg gini gini_l1 ln_canon_per_l1 cxg gestion_l1 servicios covid ldensidad zona
estat vif

* --- 5.2 Heterocedasticidad (Breusch-Pagan / Cook-Weisberg) ---
estat hettest

* --- 5.3 Normalidad de residuos (Shapiro-Wilk) ---
quietly reg gini gini_l1 ln_canon_per_l1 cxg gestion_l1 servicios covid  
predict resid_m, residuals
swilk resid_m

* --- 5.4 Especificación: prueba de Ramsey RESET ---
quietly reg gini gini_l1 ln_canon_per_l1 cxg gestion_l1 servicios covid  
estat ovtest

* --- 5.5 Autocorrelación (Wooldridge para datos de panel) ---
xtserial gini gini_l1 ln_canon_per_l1 cxg gestion_l1 servicios covid ldensidad zona

* --- 5.6 Estabilidad: comparación con Efectos Fijos y Aleatorios ---
xtreg gini gini_l1 ln_canon_per_l1 cxg gestion_l1 servicios covid ldensidad zona, fe vce(cluster id_prov)
estimates store M_FE

xtreg gini gini_l1 ln_canon_per_l1 cxg gestion_l1 servicios covid ldensidad zona, re vce(cluster id_prov)
estimates store M_RE

* Hausman (FE vs RE, sin cluster para la prueba)
quietly xtreg gini gini_l1 ln_canon_per_l1 cxg gestion_l1 servicios covid ldensidad zona, fe
estimates store fe_h
quietly xtreg gini gini_l1 ln_canon_per_l1 cxg gestion_l1 servicios covid ldensidad zona, re
estimates store re_h
hausman fe_h re_h, sigmamore

* --- 5.7 Significancia conjunta del modelo (F-test global) ---
quietly reg gini gini_l1 ln_canon_per_l1 cxg gestion_l1 servicios covid ldensidad zona
test cxg servicios covid ldensidad zona

*======================================================================*
* 6. EXPORTAR TABLA DE RESULTADOS DEL MODELO PRINCIPAL
*======================================================================*
* Requiere: ssc install estout, replace
capture which esttab
if _rc {
    ssc install estout, replace
}

esttab M_PRINCIPAL M_FE M_RE using "Resultados_Modelo.csv", ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    stats(r2 r2_a N, labels("R-cuadrado" "R-cuadrado ajustado" "Observaciones")) ///
    title("Gestión municipal y efecto redistributivo del canon minero") ///
    mtitles("Pooled Dinámico (Principal)" "Efectos Fijos" "Efectos Aleatorios") ///
    replace

esttab M_PRINCIPAL M_FE M_RE using "Resultados_Modelo.rtf", ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    stats(r2 r2_a N, labels("R-cuadrado" "R-cuadrado ajustado" "Observaciones")) ///
    title("Gestión municipal y efecto redistributivo del canon minero") ///
    mtitles("Pooled Dinámico (Principal)" "Efectos Fijos" "Efectos Aleatorios") ///
    replace

* Exportar coeficientes del modelo principal a Excel (formato simple)
quietly reg gini gini_l1 cxg servicios covid, vce(cluster id_prov)
matrix results = r(table)
putexcel set "Coeficientes_Modelo_Principal.xlsx", replace
putexcel A1 = matrix(results), names

*======================================================================*
* 7. GRÁFICOS PARA EL ANÁLISIS DE LA TESIS
*======================================================================*

* --- 7.1 Evolución del Gini promedio en el tiempo (2015-2024) ---
preserve
    collapse (mean) gini lcanon_per gestion, by(anio)
    twoway (line gini anio, lwidth(medthick) lcolor(navy)), ///
        title("Evolución del Índice de Gini promedio (2015-2024)") ///
        ytitle("Índice de Gini") xtitle("Año") ///
        xlabel(2015(1)2024) ///
        note("Fuente: elaboración propia") ///
        graphregion(color(white))
    graph export "Grafico1_Evolucion_Gini.png", replace width(1200)
restore
*==============================================**** respecto al promedio***============================*
preserve
    collapse (mean) gini lcanon_per gestion, by(anio)

    quietly summarize gini
    local prom_gini = r(mean)

    twoway ///
        (line gini anio, ///
            lwidth(medthick) ///
            lcolor(navy)) ///
        (function y=`prom_gini', ///
            range(2015 2024) ///
            lcolor(gs8) ///
            lpattern(dash) ///
            lwidth(medium)), ///
        title("Evolución del Índice de Gini promedio (2015-2024)") ///
        ytitle("Índice de Gini") ///
        xtitle("Año") ///
        xlabel(2015(1)2024) ///
        legend(order(1 "Gini promedio anual" ///
                     2 "Promedio período 2015-2024")) ///
        note("Fuente: elaboración propia") ///
        graphregion(color(white))

    graph export "Grafico1_Evolucion_Gini.png", replace width(1200)

restore

* --- 7.2 Evolución del canon (logaritmo) y gestión municipal ---
preserve
    collapse (mean) lcanon_per gestion, by(anio)
    twoway (line lcanon_per anio, yaxis(1) lcolor(maroon) lwidth(medthick)) ///
           (line gestion anio, yaxis(2) lcolor(navy) lwidth(medthick) lpattern(dash)), ///
        title("Evolución del Ln(Canon) y la Gestión Municipal") ///
        ytitle("Ln(Canon)", axis(1)) ytitle("Índice de Gestión", axis(2)) ///
        xtitle("Año") xlabel(2015(1)2024) ///
        legend(order(1 "Ln(Canon)" 2 "Gestión municipal")) ///
        graphregion(color(white))
    graph export "Grafico2_Canon_Gestion.png", replace width(1200)
restore

* --- 7.3 Relación entre la interacción (Canon x Gestión) y el Gini ---
twoway (scatter gini cxg, mcolor(navy%50)) ///
       (lfit gini cxg, lcolor(red) lwidth(medthick)), ///
    title("Relación entre Ln(Canon) x Gestión y el Índice de Gini") ///
    ytitle("Índice de Gini") xtitle("Ln(Canon) x Gestión municipal") ///
    legend(order(1 "Observaciones" 2 "Ajuste lineal")) ///
    graphregion(color(white))
graph export "Grafico3_Interaccion_vs_Gini.png", replace width(1200)

* --- 7.4 Comparación del Gini por provincia (promedio 2015-2024) ---
preserve
    collapse (mean) gini lcanon_per gestion, by(prov)
    graph hbar gini, over(prov, sort(gini)) ///
        title("Índice de Gini promedio por provincia (2015-2024)") ///
        ytitle("Índice de Gini") ///
        graphregion(color(white))
    graph export "Grafico4_Gini_por_Provincia.png", replace width(1200)
restore

* --- 7.5 Dispersión: Gestión municipal vs Gini, coloreado por provincia ---
preserve
    collapse (mean) gini gestion lcanon_per, by(prov)
    twoway (scatter gini gestion, mlabel(prov) mcolor(navy) msize(medium)) ///
           (lfit gini gestion, lcolor(red)), ///
        title("Gestión municipal vs. Índice de Gini (promedio por provincia)") ///
        ytitle("Índice de Gini") xtitle("Índice de gestión municipal") ///
        legend(order(1 "Provincias" 2 "Ajuste lineal")) ///
        graphregion(color(white))
    graph export "Grafico5_Gestion_vs_Gini.png", replace width(1200)
restore

* --- 7.6 Boxplot del Gini antes y después / durante COVID ---
graph box gini, over(covid, relabel(1 "Sin COVID" 2 "Con COVID")) ///
    title("Distribución del Índice de Gini según periodo COVID") ///
    ytitle("Índice de Gini") ///
    graphregion(color(white))
graph export "Grafico6_Gini_COVID.png", replace width(1200)

* --- 7.7 Valores observados vs predichos del modelo principal ---
quietly reg gini gini_l1 cxg servicios covid
predict gini_hat
twoway (scatter gini gini_hat, mcolor(navy%50)) ///
       (lfit gini_hat gini_hat, lcolor(red) lwidth(medthick)), ///
    title("Valores observados vs. predichos - Modelo principal") ///
    ytitle("Gini observado") xtitle("Gini predicho") ///
    legend(order(1 "Observaciones" 2 "Línea de ajuste 45°")) ///
    graphregion(color(white))
graph export "Grafico7_Observado_vs_Predicho.png", replace width(1200)

* --- 7.8 Distribución de residuos del modelo principal ---
histogram resid_m, normal ///
    title("Distribución de los residuos del modelo principal") ///
    xtitle("Residuos") ytitle("Densidad") ///
    graphregion(color(white))
graph export "Grafico8_Distribucion_Residuos.png", replace width(1200)
* --- 7.9 mapa de burbujas de densidad y gini---
preserve

collapse (mean) gini ldensidad lcanon_per, by(prov)

levelsof prov, local(provs)

local i = 1
local graficos
local orden

foreach p of local provs {

    local graficos `graficos' ///
    (scatter gini ldensidad if prov=="`p'", ///
        msymbol(O) ///
        msize(*1.5))

    local orden `orden' `i' "`p'"
    local ++i
}

twoway `graficos', ///
title("Desigualdad, densidad y canon minero") ///
xtitle("Ln(Densidad poblacional)") ///
ytitle("Índice de Gini") ///
legend(order(`orden') ///
       cols(1) ///
       position(3) ///
       ring(0) ///
       size(small)) ///
graphregion(color(white))

restore
*======================================================================*
* 8. RESUMEN FINAL EN PANTALLA
*======================================================================*
esttab M_PRINCIPAL M_FE M_RE ///
using "C:\Users\Paul\Documents\Mi tesis\modelo ods\Tabla_Resultados.rtf", ///
replace ///
title("Determinantes de la desigualdad de ingresos") ///
mtitles("Modelo Principal" "FE" "RE") ///
cells(b(star fmt(4)) se(par fmt(4))) ///
star(* 0.10 ** 0.05 *** 0.01) ///
stats(N r2, fmt(0 4)) ///
label

*======================================================================*
* FIN
*======================================================================*
