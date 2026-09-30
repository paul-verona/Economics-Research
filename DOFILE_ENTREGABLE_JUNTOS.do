/*===========================================================================
  TESIS: Movilidad social intergeneracional en la dimensión ocupacional
         y el Programa Juntos en Perú
  Fuente : Young Lives Perú - Cohorte Mayor (Rondas 1 a 7)
  Autor  : Paul
  Fecha  : Junio 2026

  ESTRUCTURA

    PARTE 0 : Configuración general
    PARTE 1 : Armonización de identificadores
    PARTE 2 : Extracción de variables por ronda
    PARTE 3 : Integración longitudinal
    PARTE 4 : Diagnóstico de valores perdidos
    PARTE 5 : Construcción de variables analíticas
    PARTE 6 : Estadísticas descriptivas
    PARTE 7 : Movilidad ocupacional intergeneracional
    PARTE 8 : Propensity Score Matching
    PARTE 9 : Ordered Logit
    PARTE 10: Exportación de resultados

===========================================================================*/

clear all
set more off
set maxvar 5000
version 19
*===========================================================================
* PARTE 0 : CONFIGURACIÓN GENERAL
*===========================================================================

global data   "C:\Users\Paul\Documents\tesis young\DatosR1R2R3R4R5R6R7"

global output ///
"C:\Users\Paul\Documents\tesis young\DatosR1R2R3R4R5R6R7\resultados"

capture mkdir "$output"
*===========================================================================
* INSTALACIÓN DE PAQUETES
*===========================================================================

capture which psmatch2
if _rc ssc install psmatch2, replace
capture which esttab
if _rc ssc install estout, replace
capture which outreg2
if _rc ssc install outreg2, replace
capture which mdesc
if _rc ssc install mdesc, replace
*===========================================================================
* PARTE 1 : ARMONIZACIÓN DEL IDENTIFICADOR
*===========================================================================

capture program drop armonizar_id

program define armonizar_id


    capture confirm string variable CHILDCODE
    if !_rc {
        gen long id_nino = real(substr(CHILDCODE,3,.))
    }

    else {
        gen long id_nino = CHILDCODE
    }
    label variable id_nino ///
    "Identificador único del niño"
end
/*---------------------------------------------------------------------------
  2.1 RONDA 1 (2002, ~8 años)

  Línea base del panel

  Incluye:
   - Características del hogar
   - Educación y ocupación de madre y padre
   - Índice de riqueza
   - Etnicidad
   - Antropometría
---------------------------------------------------------------------------*/

use "$data\Ronda 1 lista.dta", clear

armonizar_id
keep id_nino ///
     sex ///
     hhsize ///
     typesite ///
     region ///
     motheth ///
     chldeth ///
     wi ///
     ocup_madre_r1 ///
     ocup_padre_r1 ///
     yrschool_madre ///
     yrschool_padre ///
     grado_madre ///
     grado_padre ///
     anhos_madre ///
     anhos_padre ///
     daddead ///
     momlive ///
     bmi ///
     zhfa ///
     zwfa ///
     zbfa ///
     agemon
rename sex              sexo
rename hhsize           tam_hogar_r1
rename typesite         zona_r1
rename region           region_r1
rename motheth          etnia_madre_r1
rename chldeth          etnia_nino_r1
rename wi               wi_r1
*---------------------------------------
* OCUPACIÓN DE LOS PADRES
*---------------------------------------

rename ocup_madre_r1 ocup_madre_r1_cod
rename ocup_padre_r1 ocup_padre_r1_cod

*---------------------------------------
* EDUCACIÓN DE LOS PADRES
*---------------------------------------

rename yrschool_madre educ_madre_nivel_r1
rename yrschool_padre educ_padre_nivel_r1
rename grado_madre grado_madre_r1
rename grado_padre grado_padre_r1
rename anhos_madre educ_madre_anios_r1
rename anhos_padre educ_padre_anios_r1
*---------------------------------------
* OTRAS VARIABLES
*---------------------------------------

rename daddead padre_fallecido_r1
rename momlive madre_vive_r1
rename bmi   bmi_r1
rename zhfa  zhfa_r1
rename zwfa  zwfa_r1
rename zbfa  zbfa_r1

rename agemon edad_meses_r1
*---------------------------------------
* LABELS
*---------------------------------------
label define zona_lbl ///
1 "Rural" ///
2 "Urbano", replace

label values zona_r1 zona_lbl
label define region_lbl ///
31 "Sierra" ///
32 "Costa" ///
33 "Selva", replace

label values region_r1 region_lbl

*---------------------------------------
* DIAGNÓSTICOS
*---------------------------------------

duplicates report id_nino

capture isid id_nino
if _rc {

    di as error "ERROR: id_nino duplicado en R1"

    exit 459
}
describe

count
save "$output\r1.dta", replace
/*---------------------------------------------------------------------------
  2.2  RONDA 2 (2006, ~niño de 12 años)
       - Educación, sector e ingreso de MADRE y PADRE
       - Activos del hogar, riqueza
---------------------------------------------------------------------------*/
use "$data\Ronda 2 lista.dta", clear
armonizar_id

keep id_nino wi educ_madre educ_padre sector_madre sector_padre ///
     actprin_madre actprin_padre tipoemp_madre tipoemp_padre ///
     ingreso_madre ingreso_padre aniosocup_madre aniosocup_padre ///
     mesesocup_madre mesesocup_padre totalexp_pc foodexp_pc ///
     bmi zhfa zwfa zbfa agemon mumlive dadlive

rename wi              wi_r2
rename educ_madre      educ_madre_anios_r2
rename educ_padre      educ_padre_anios_r2
rename sector_madre    sector_madre_r2
rename sector_padre    sector_padre_r2
rename actprin_madre   actprin_madre_r2
rename actprin_padre   actprin_padre_r2
rename tipoemp_madre   tipoemp_madre_r2
rename tipoemp_padre   tipoemp_padre_r2
rename ingreso_madre   ingreso_madre_r2
rename ingreso_padre   ingreso_padre_r2
rename aniosocup_madre anios_ocup_madre_r2
rename aniosocup_padre anios_ocup_padre_r2
rename mesesocup_madre meses_ocup_madre_r2
rename mesesocup_padre meses_ocup_padre_r2
rename totalexp_pc     gasto_pc_r2
rename foodexp_pc      gasto_alim_pc_r2
rename bmi             bmi_r2
rename zhfa            zhfa_r2
rename zwfa            zwfa_r2
rename zbfa            zbfa_r2
rename agemon          edad_meses_r2
rename mumlive         madre_vive_r2
rename dadlive         padre_vive_r2

save "$output\r2.dta", replace

duplicates report id_nino

capture isid id_nino

if _rc {
    di as error "ERROR: id_nino duplicado en R2"
    exit 459
}

describe
count

*/---------------------------------------------------------------------------
  *2.3  RONDA 3 (2009, ~niño de 15 años)
  *     - VARIABLE DE TRATAMIENTO: juntosr3 (Programa Juntos)
   *    - Edad y educación de MADRE y PADRE
 *      - Actividad principal, riqueza, gasto, tamaño hogar
  *     - Pruebas cognitivas del niño (PPVT, Cloze, Math)

use "$data\Ronda 3 lista.dta", clear
armonizar_id

keep id_nino juntosr3 edad_madre edad_padre educ_madre educ_padre ///
     actividad_principal actidr3 wi tam_hogar ingreso_dep ///
     totalexp_pc foodexp_pc ppvt cloze math ///
     bmi zhfa zwfa zbfa agemon sex

rename juntosr3             juntos
rename edad_madre           edad_madre_r3
rename edad_padre           edad_padre_r3
rename educ_madre           educ_madre_anios_r3
rename educ_padre           educ_padre_anios_r3
rename actividad_principal  ocup_madre_r3_cod
rename actidr3              act_id_r3
rename wi                   wi_r3
rename tam_hogar            tam_hogar_r3
rename ingreso_dep          ingreso_hogar_r3
rename totalexp_pc          gasto_pc_r3
rename foodexp_pc           gasto_alim_pc_r3
rename ppvt                 ppvt_r3
rename cloze                cloze_r3
rename math                 math_r3
rename bmi                  bmi_r3
rename zhfa                 zhfa_r3
rename zwfa                 zwfa_r3
rename zbfa                 zbfa_r3
rename agemon               edad_meses_r3
rename sex                  sexo_r3

label define juntos_lbl ///
0 "No beneficiario" ///
1 "Beneficiario", replace

label values juntos juntos_lbl

label variable juntos ///
"Participación en Programa Juntos (R3, ~2009)"

save "$output\r3.dta", replace

duplicates report id_nino

capture isid id_nino

if _rc {
    di as error "ERROR: id_nino duplicado en R3"
    exit 459
}

describe
count
/*---------------------------------------------------------------------------
  2.4  RONDA 4 (2013, ~niño de 19 años)
       - Educación alcanzada, capacitación, situación laboral del joven
---------------------------------------------------------------------------*/
use "$data\Ronda 4 lista.dta", clear
armonizar_id

keep id_nino HGHQULR4 TYPQULR4 ENRSCHR4 TRAINGR4 STDLGR4 ///
     CURJOBR4 W12MEMR4 LOKWRKR4 ///
     MRTSTSR4 NUMCHDR4 bmi zhfa zbfa fhfa fbfa agemon GENDER

rename HGHQULR4  educ_maxima_r4
rename TYPQULR4  tipo_educ_r4
rename ENRSCHR4  matriculado_r4
rename TRAINGR4  capacitacion_r4
rename STDLGR4   educ_superior_actual_r4
rename CURJOBR4  trabaja_r4
rename W12MEMR4  trabajo_12m_r4
rename LOKWRKR4  busca_trabajo_r4
rename MRTSTSR4  estado_civil_r4
rename NUMCHDR4  num_hijos_r4
rename bmi       bmi_r4
rename zhfa      zhfa_r4
rename zbfa      zbfa_r4
rename fhfa      fhfa_r4
rename fbfa      fbfa_r4
rename agemon    edad_meses_r4
rename GENDER    sexo_r4

label variable sexo_r4 ///
"Sexo del joven (R4)"

label variable educ_superior_actual_r4 ///
"Actualmente cursa educación superior (R4)"

save "$output\r4.dta", replace

duplicates report id_nino

capture isid id_nino

if _rc {
    di as error "ERROR: id_nino duplicado en R4"
    exit 459
}

describe
count


*/---------- 2.5  RONDA 5 (2016, ~niño de 22 años)
    *   - Educación superior, capacitación, mercado laboral*/

use "$data\Ronda 5 lista.dta", clear
armonizar_id

keep id_nino HGHQULR5 TYPQULR5 ENRSCHR5 TRAINGR5 STDLGR5 APPUNIR5 ///
     CURJOBR5 W12MEMR5 LOKWRKR5 ACTMAIN MRTSTSR5 NUMCHDR5 ///
     bmi agemon CHGNDRR5

rename HGHQULR5  educ_maxima_r5
rename TYPQULR5  tipo_educ_r5
rename ENRSCHR5  matriculado_r5
rename TRAINGR5  capacitacion_r5
rename STDLGR5   educ_superior_actual_r5
rename APPUNIR5  postulo_uni_r5
rename CURJOBR5  trabaja_r5
rename W12MEMR5  trabajo_12m_r5
rename LOKWRKR5  busca_trabajo_r5
rename ACTMAIN   actividad_principal_r5
rename MRTSTSR5  estado_civil_r5
rename NUMCHDR5  num_hijos_r5
rename bmi       bmi_r5
rename agemon    edad_meses_r5
rename CHGNDRR5  sexo_r5

label variable actividad_principal_r5 ///
"Actividad principal del joven (R5)"

label variable sexo_r5 ///
"Sexo del joven (R5)"

save "$output\r5.dta", replace

duplicates report id_nino

capture isid id_nino

if _rc {
    di as error "ERROR: id_nino duplicado en R5"
    exit 459
}

describe
count

/*---------------------------------------------------------------------------
  2.6  RONDA 6 (2020–2021, encuestas telefónicas COVID)

  Incluye información de las encuestas telefónicas COV5 y, como respaldo,
  variables seleccionadas de COV3 y COV2.

  Se extrae información sobre educación, empleo, ingresos, estado civil,
  salud mental y choques económicos asociados a la pandemia.
---------------------------------------------------------------------------*/

use "$data\Ronda 6 lista.dta", clear
armonizar_id

keep id_nino tam_hogar ///
     cureducov5 curgrdcov5 curshcov5 stpeducov5 ///
     wrk1hrcov5 curjobcov5 mainactcov5 typwrkcov5 ///
     econsec1cov5 econsec2cov5 totearncov5 hlthinscov5 ///
     marstatcov5 mthmarcov5 yrmarcov5 ///
     anxtycov5_1 phq8cov5_1 incchgcov5 ///
     CUREDUCOV3 CURGRDCOV3 CURJOBCOV3 TYPWRKCOV3 ECNSECCOV3 ///
     WRK1HRCOV3 MRTM01COV2

rename tam_hogar        tam_hogar_r6

rename cureducov5       matriculado_r6
rename curgrdcov5       grado_actual_r6
rename curshcov5        institucion_r6
rename stpeducov5       dejo_estudios_r6

rename wrk1hrcov5       trabajo_1h_r6
rename curjobcov5       tiene_trabajo_r6
rename mainactcov5      actividad_principal_r6
rename typwrkcov5       tipo_trabajo_r6
rename econsec1cov5     sector_econ1_r6
rename econsec2cov5     sector_econ2_r6
rename totearncov5      ingreso_total_r6

rename hlthinscov5      seguro_salud_r6

rename marstatcov5      estado_civil_r6
rename mthmarcov5       mes_matrimonio_r6
rename yrmarcov5        anio_matrimonio_r6

rename anxtycov5_1      ansiedad_r6
rename phq8cov5_1       depresion_r6

rename incchgcov5       cambio_ingreso_covid_r6


* Variables de respaldo (COV3/COV2)

rename CUREDUCOV3       matriculado_r6_cov3
rename CURGRDCOV3       grado_actual_r6_cov3
rename CURJOBCOV3       tiene_trabajo_r6_cov3
rename TYPWRKCOV3       tipo_trabajo_r6_cov3
rename ECNSECCOV3       sector_econ_r6_cov3
rename WRK1HRCOV3       trabajo_1h_r6_cov3

rename MRTM01COV2       estado_civil_r6_cov2


save "$output\r6.dta", replace


duplicates report id_nino

capture isid id_nino

if _rc {

    di as error "ERROR: id_nino duplicado en R6"

    exit 459

}

describe

count

/*---------------------------------------------------------------------------
  2.7  RONDA 7 (2023, ~29 años)

  Variable dependiente principal:
  ocupación/actividad principal del adulto.

  Incluye educación máxima alcanzada, capacitación laboral,
  antecedentes de matrimonio y algunas condiciones de salud.
---------------------------------------------------------------------------*/

use "$data\Ronda 7 lista.dta", clear
armonizar_id


keep id_nino age_cal mainactr7 typwrk7r7 econsec7r7 smmainactr7 ///
     employer7r7 ntearncsh7r7 wrkhrs7r7 wrkmth7r7 ///
     lstqualr7 lstqualtypr7 lstqualmajr7 wrktrngr7 numtrngr7 ///
     curredur7 ///
     evrmar1r7 evrmar2r7 wrkspsr7 ///
     hgbpr7 hgchlstr7 dbtsr7 ///
     anxtyr7_1 phq8r7_1 ///
     typesite regionr7 clustidr7



rename age_cal           edad_r7

rename mainactr7         actividad_hijo
rename typwrk7r7         tipo_trabajo_hijo
rename econsec7r7        sector_hijo

rename smmainactr7       trabaja_hijo
rename employer7r7       relacion_laboral_hijo

rename ntearncsh7r7      ingreso_efectivo_hijo
rename wrkhrs7r7         horas_trabajo_hijo
rename wrkmth7r7         meses_trabajo_hijo


rename lstqualr7         educ_maxima_r7
rename lstqualtypr7      tipo_educ_r7
rename lstqualmajr7      carrera_r7

rename wrktrngr7         capacitacion_r7
rename numtrngr7         num_capacitaciones_r7

rename curredur7         matriculado_r7


rename evrmar1r7         casado_alguna_vez_r7
rename evrmar2r7         convivio_alguna_vez_r7

rename wrkspsr7          conyuge_trabaja_r7


rename hgbpr7            hipertension_r7
rename hgchlstr7         colesterol_alto_r7
rename dbtsr7            diabetes_r7

rename anxtyr7_1         ansiedad_r7
rename phq8r7_1          depresion_r7


rename typesite          zona_r7
rename regionr7          region_r7
rename clustidr7         cluster_r7


label variable actividad_hijo ///
"Actividad principal del adulto (R7)"

label variable educ_maxima_r7 ///
"Máximo nivel educativo alcanzado (R7)"

label variable capacitacion_r7 ///
"Capacitación laboral recibida (R7)"


save "$output\r7.dta", replace


duplicates report id_nino

capture isid id_nino

if _rc {

    di as error "ERROR: id_nino duplicado en R7"

    exit 459

}

describe

count

*===========================================================================
* PARTE 3: INTEGRACIÓN LONGITUDINAL
*===========================================================================

/*===========================================================================
* PARTE 3: INTEGRACIÓN LONGITUDINAL
* Objetivo: construir un panel balanceado con individuos observados
* en las siete rondas de Young Lives.
*===========================================================================*/

use "$output\r1.dta", clear

isid id_nino

merge 1:1 id_nino using "$output\r2.dta", keep(match) nogen
display "Observaciones después de R2:"
count

merge 1:1 id_nino using "$output\r3.dta", keep(match) nogen
display "Observaciones después de R3:"
count

merge 1:1 id_nino using "$output\r4.dta", keep(match) nogen
display "Observaciones después de R4:"
count

merge 1:1 id_nino using "$output\r5.dta", keep(match) nogen
display "Observaciones después de R5:"
count

merge 1:1 id_nino using "$output\r6.dta", keep(match) nogen
display "Observaciones después de R6:"
count

merge 1:1 id_nino using "$output\r7.dta", keep(match) nogen
display "Observaciones después de R7:"
count


duplicates report id_nino

capture isid id_nino

if _rc {
    di as error "ERROR: id_nino no es único luego de los merges"
    exit 459
}

display _newline "======================================="
display "BASE LONGITUDINAL BALANCEADA"
display "======================================="
count
describe, short

save "$output\base_longitudinal_completa.dta", replace

*===========================================================================
* PARTE 4: DIAGNÓSTICO DE VALORES PERDIDOS (MISSING VALUES)
*===========================================================================

capture log close

log using "$output\diagnostico_missing.log", replace text

use "$output\base_longitudinal_completa.dta", clear


display "====================================================="
display "DIAGNOSTICO DE VALORES PERDIDOS"
display "====================================================="

display ""
display "Numero total de observaciones:"
count

*---------------------------------------------------------------------------
* Variables principales
*---------------------------------------------------------------------------

local vars_clave ///
juntos ///
ocup_madre_r1_cod ///
ocup_padre_r1_cod ///
educ_madre_anios_r1 ///
educ_padre_anios_r1 ///
wi_r1 ///
tam_hogar_r1 ///
zona_r1 ///
region_r1 ///
sexo ///
actividad_hijo ///
tipo_trabajo_hijo ///
sector_hijo ///
educ_maxima_r7 ///
capacitacion_r7 ///
ingreso_efectivo_hijo



display ""
display "====================================================="
display "RESUMEN GENERAL DE MISSING VALUES"
display "====================================================="

mdesc `vars_clave'



display ""
display "====================================================="
display "PORCENTAJE DE MISSING POR VARIABLE"
display "====================================================="


foreach var of local vars_clave {


capture confirm variable `var'


if !_rc {


quietly count

local total = r(N)



quietly count if missing(`var')

local nmiss = r(N)



local pct = 100*`nmiss'/`total'



display ///
"`var': " ///
%6.2f `pct' ///
"% missing (" ///
`nmiss' ///
"/" ///
`total' ///
")"



}

}


*---------------------------------------------------------------------------
* ATRICION DEL PANEL
*---------------------------------------------------------------------------

display ""
display "====================================================="
display "ATRICION DEL PANEL"
display "====================================================="


capture drop presente_r2 presente_r3 presente_r4 ///
presente_r5 presente_r6 presente_r7

gen presente_r2 = !missing(wi_r2)

gen presente_r3 = !missing(juntos)

gen presente_r4 = !missing(educ_maxima_r4)

gen presente_r5 = !missing(educ_maxima_r5)

* R6 utiliza varias fuentes COVID


gen presente_r6 = ///
!missing(matriculado_r6) | ///
!missing(tiene_trabajo_r6) | ///
!missing(estado_civil_r6)

gen presente_r7 = !missing(actividad_hijo)
local N = _N


foreach r in r2 r3 r4 r5 r6 r7 {


quietly count if presente_`r'==1


display ///
"Presentes en `r': " ///
r(N) ///
" de `N'"


}

*---------------------------------------------------------------------------
* ATRICION SEGUN JUNTOS
*---------------------------------------------------------------------------


display ""

display "====================================================="

display "ATRICION EN R7 SEGUN JUNTOS"

display "====================================================="

tab juntos presente_r7, row chi2

*---------------------------------------------------------------------------
* MUESTRA EFECTIVA MADRE-HIJO
*---------------------------------------------------------------------------

display ""

display "====================================================="

display "MUESTRA EFECTIVA MADRE-HIJO"

display "====================================================="

capture drop muestra_madre

gen muestra_madre = 1

replace muestra_madre = 0 if missing(juntos)
replace muestra_madre = 0 if missing(ocup_madre_r1_cod)
replace muestra_madre = 0 if missing(actividad_hijo)
replace muestra_madre = 0 if missing(wi_r1)
replace muestra_madre = 0 if missing(tam_hogar_r1)

label variable muestra_madre "Muestra efectiva madre-hijo"

tab muestra_madre
count if muestra_madre==1
display "Observaciones validas madre-hijo: " r(N)

*---------------------------------------------------------------------------
* MUESTRA EFECTIVA PADRE-HIJO
*---------------------------------------------------------------------------
display ""

display "====================================================="

display "MUESTRA EFECTIVA PADRE-HIJO"

display "====================================================="
capture drop muestra_padre

gen muestra_padre = 1

replace muestra_padre = 0 if missing(juntos)
replace muestra_padre = 0 if missing(ocup_padre_r1_cod)
replace muestra_padre = 0 if missing(educ_padre_anios_r1)
replace muestra_padre = 0 if missing(actividad_hijo)
replace muestra_padre = 0 if missing(wi_r1)
replace muestra_padre = 0 if missing(tam_hogar_r1)

label variable muestra_padre "Muestra efectiva padre-hijo"

tab muestra_padre
count if muestra_padre==1
display "Observaciones validas padre-hijo: " r(N)

*---------------------------------------------------------------------------
* MUESTRA COMPLETA
*---------------------------------------------------------------------------

display ""

display "====================================================="
display "MUESTRA COMPLETA"
display "====================================================="

capture drop muestra_completa

gen muestra_completa = 1

replace muestra_completa = 0 if missing(juntos)
replace muestra_completa = 0 if missing(ocup_madre_r1_cod)
replace muestra_completa = 0 if missing(ocup_padre_r1_cod)
replace muestra_completa = 0 if missing(actividad_hijo)
replace muestra_completa = 0 if missing(educ_madre_anios_r1)
replace muestra_completa = 0 if missing(educ_padre_anios_r1)
replace muestra_completa = 0 if missing(wi_r1)
replace muestra_completa = 0 if missing(tam_hogar_r1)
replace muestra_completa = 0 if missing(zona_r1)

label variable muestra_completa ///
"Muestra completa para modelos"

tab muestra_completa

count if muestra_completa==1

display "Observaciones completas: " r(N)

display ""
display "====================================================="
display "FIN DEL DIAGNOSTICO"
display "====================================================="

capture log close
*===========================================================================
* PARTE 5: CONSTRUCCIÓN DE VARIABLES ANALÍTICAS
*===========================================================================
use "$output\base_longitudinal_completa.dta", clear


describe ingreso*

describe educ_madre*

describe educ_padre*

/*---------------------------------------------------------------------------
  5.1 CATEGORÍAS OCUPACIONALES (4 niveles jerárquicos)
---------------------------------------------------------------------------*/

capture label drop ocup_lbl

label define ocup_lbl                                      ///
        1 "Agricultura/Primario"                           ///
        2 "Manual/Industrial"                             ///
        3 "Comercio/Servicios"                            ///
        4 "Técnico/Profesional", replace


*-------------------------
* MADRE
*-------------------------

capture drop ocup_madre_cat

gen ocup_madre_cat = .

replace ocup_madre_cat = 1 if inlist(ocup_madre_r1_cod,61,92,93)

replace ocup_madre_cat = 2 if ///
inlist(ocup_madre_r1_cod,71,72,73,74,81,82,83,91)

replace ocup_madre_cat = 3 if ///
inlist(ocup_madre_r1_cod,51,52)

replace ocup_madre_cat = 4 if ///
inlist(ocup_madre_r1_cod,21,22,23,24,31,32,33,34,41,42)


label values ocup_madre_cat ocup_lbl

label variable ocup_madre_cat ///
"Categoría ocupacional de la madre (R1, CIUO-88)"



*-------------------------
* PADRE
*-------------------------

capture drop ocup_padre_cat

gen ocup_padre_cat = .

replace ocup_padre_cat = 1 if ///
inlist(ocup_padre_r1_cod,1,61,92,93)

replace ocup_padre_cat = 2 if ///
inlist(ocup_padre_r1_cod,71,72,73,74,81,82,83,91)

replace ocup_padre_cat = 3 if ///
inlist(ocup_padre_r1_cod,51,52)

replace ocup_padre_cat = 4 if ///
inlist(ocup_padre_r1_cod,21,22,23,24,31,32,33,34,41,42)


label values ocup_padre_cat ocup_lbl

label variable ocup_padre_cat ///
"Categoría ocupacional del padre (R1, CIUO-88)"



tab ocup_madre_cat, missing
tab ocup_padre_cat, missing



/*---------------------------------------------------------------------------
  5.2 CATEGORÍA OCUPACIONAL DEL HIJO/A
---------------------------------------------------------------------------*/

capture drop ocup_hijo


gen ocup_hijo = .


replace ocup_hijo = 1 if inlist(sector_hijo,1,2)

replace ocup_hijo = 2 if inlist(sector_hijo,3,4,5,6)

replace ocup_hijo = 3 if inrange(sector_hijo,7,14)

replace ocup_hijo = 4 if inrange(sector_hijo,15,20)



replace ocup_hijo = 3 ///
if missing(ocup_hijo) & trabaja_hijo==1 & ///
inlist(tipo_trabajo_hijo,9,10)


replace ocup_hijo = 1 ///
if missing(ocup_hijo) & trabaja_hijo==1 & ///
tipo_trabajo_hijo==21


label values ocup_hijo ocup_lbl


label variable ocup_hijo ///
"Categoría ocupacional del hijo/a (R7)"



tab ocup_hijo, missing



/*---------------------------------------------------------------------------
  5.3 MOVILIDAD OCUPACIONAL
---------------------------------------------------------------------------*/

capture drop movilidad_bruta_m movilidad_madre
capture drop ascendente_madre descendente_madre inmovil_madre

capture drop movilidad_bruta_p movilidad_padre
capture drop ascendente_padre descendente_padre inmovil_padre



gen movilidad_bruta_m = ocup_hijo-ocup_madre_cat


gen movilidad_madre = .


replace movilidad_madre=1 if movilidad_bruta_m<0
replace movilidad_madre=2 if movilidad_bruta_m==0
replace movilidad_madre=3 if movilidad_bruta_m>0



capture label drop mov_lbl

label define mov_lbl 1 "Descendente" ///
                     2 "Inmovilidad" ///
                     3 "Ascendente"


label values movilidad_madre mov_lbl



gen ascendente_madre=(movilidad_madre==3) ///
if !missing(movilidad_madre)

gen descendente_madre=(movilidad_madre==1) ///
if !missing(movilidad_madre)

gen inmovil_madre=(movilidad_madre==2) ///
if !missing(movilidad_madre)




gen movilidad_bruta_p = ocup_hijo-ocup_padre_cat


gen movilidad_padre = .


replace movilidad_padre=1 if movilidad_bruta_p<0
replace movilidad_padre=2 if movilidad_bruta_p==0
replace movilidad_padre=3 if movilidad_bruta_p>0


label values movilidad_padre mov_lbl



gen ascendente_padre=(movilidad_padre==3) ///
if !missing(movilidad_padre)

gen descendente_padre=(movilidad_padre==1) ///
if !missing(movilidad_padre)

gen inmovil_padre=(movilidad_padre==2) ///
if !missing(movilidad_padre)




/*---------------------------------------------------------------------------
  5.4 VARIABLES DE CONTROL
---------------------------------------------------------------------------*/

capture drop urbano

gen urbano=(zona_r1==2) if !missing(zona_r1)



capture drop region_sierra
capture drop region_selva


gen region_sierra=(region_r1==31)

gen region_selva=(region_r1==33)



capture drop indigena


gen indigena=inlist(etnia_madre_r1,31,33,34) ///
if !missing(etnia_madre_r1)



capture drop hombre


gen hombre=(sexo==1) ///
if !missing(sexo)



label variable urbano "Zona urbana"

label variable indigena "Hogar indígena"

label variable hombre "Sexo masculino"

label variable wi_r1 "Índice de riqueza"

label variable tam_hogar_r1 "Tamaño del hogar"




/*---------------------------------------------------------
5.5 EDUCACIÓN DE LOS PADRES
---------------------------------------------------------*/

capture drop educ_padre_ord
capture drop educ_madre_ord


*==========================
* PADRE
*==========================

gen educ_padre_ord = .

replace educ_padre_ord = 1 if inlist(educ_padre_nivel_r1,0,33)

replace educ_padre_ord = 2 if educ_padre_nivel_r1==34

replace educ_padre_ord = 3 if inlist(educ_padre_nivel_r1,35,36,37,38)



*==========================
* MADRE
*==========================

gen educ_madre_ord = .

replace educ_madre_ord = 1 if inlist(educ_madre_nivel_r1,0,33)

replace educ_madre_ord = 2 if educ_madre_nivel_r1==34

replace educ_madre_ord = 3 if inlist(educ_madre_nivel_r1,35,36,37,38)




capture label drop edu_lbl

label define edu_lbl 1 "Primaria o menos" ///
                     2 "Secundaria" ///
                     3 "Superior"

label values educ_padre_ord edu_lbl
label values educ_madre_ord edu_lbl



label variable educ_padre_ord ///
"Nivel educativo del padre"

label variable educ_madre_ord ///
"Nivel educativo de la madre"



tab educ_padre_ord

tab educ_madre_ord

/*---------------------------------------------------------------------------
  5.6 INGRESOS DE LOS PADRES
---------------------------------------------------------------------------*/

capture confirm variable ingreso_madre_r2

if !_rc {capture drop ingreso_madre
capture drop ln_ingreso_madre
gen ingreso_madre = ingreso_madre_r2 ///
if !missing(ingreso_madre_r2)
gen ln_ingreso_madre = ///
ln(ingreso_madre+1) ///
if !missing(ingreso_madre)
}

capture confirm variable ingreso_padre_r2

if !_rc {capture drop ingreso_padre
capture drop ln_ingreso_padre
gen ingreso_padre = ingreso_padre_r2 ///
if !missing(ingreso_padre_r2)
gen ln_ingreso_padre = ///
ln(ingreso_padre+1) ///
if !missing(ingreso_padre)
}
label variable ingreso_madre ///
"Ingreso laboral de la madre"

label variable ingreso_padre ///
"Ingreso laboral del padre"
/*---------------------------------------------------------------------------
  5.7 EDUCACIÓN Y CAPACITACIÓN DEL HIJO
---------------------------------------------------------------------------*/

capture drop educ_maxima
capture drop educ_superior
capture drop capacitacion



gen educ_maxima=educ_maxima_r7


replace educ_maxima=educ_maxima_r5 ///
if missing(educ_maxima)

replace educ_maxima=educ_maxima_r4 ///
if missing(educ_maxima)



gen educ_superior=(educ_maxima>=4) ///
if !missing(educ_maxima)




gen capacitacion=capacitacion_r7


replace capacitacion=capacitacion_r5 ///
if missing(capacitacion)

replace capacitacion=capacitacion_r4 ///
if missing(capacitacion)




/*---------------------------------------------------------------------------
  5.8 EDAD DEL HIJO
---------------------------------------------------------------------------*/

label variable edad_r7 ///
"Edad del hijo/a en años"



capture drop edad_r7_sq


gen edad_r7_sq=edad_r7^2



label variable edad_r7_sq ///
"Edad al cuadrado"




/*---------------------------------------------------------------------------
  5.9 MUESTRA ANALÍTICA
---------------------------------------------------------------------------*/

capture drop muestra_base
capture drop muestra_madre
capture drop muestra_padre
capture drop muestra_ambos



gen muestra_base = ///
!missing(ocup_hijo) & ///
!missing(juntos) & ///
!missing(wi_r1) & ///
!missing(tam_hogar_r1) & ///
!missing(urbano)



gen muestra_madre = ///
muestra_base==1 & ///
!missing(ocup_madre_cat)



gen muestra_padre = ///
muestra_base==1 & ///
!missing(ocup_padre_cat)



gen muestra_ambos = ///
muestra_madre==1 & ///
muestra_padre==1



tab muestra_base
tab muestra_madre
tab muestra_padre
tab muestra_ambos


count if muestra_base==1
count if muestra_madre==1
count if muestra_padre==1
count if muestra_ambos==1



save "$output\base_analitica.dta", replace

*===========================================================================
* PARTE 6: ESTADÍSTICAS DESCRIPTIVAS
*===========================================================================

capture log close
log using "$output\estadisticas_descriptivas.log", replace


display "======================================================"
display "ESTADÍSTICAS DESCRIPTIVAS"
display "======================================================"


****************************************************
* 6.1 Variables continuas
****************************************************

summ ///
wi_r1 ///
tam_hogar_r1 ///
edad_r7 ///
ln_ingreso_madre ///
ln_ingreso_padre ///
educ_madre_ord ///
educ_padre_ord ///
if muestra_padre==1, detail



****************************************************
* 6.2 Variables categóricas
****************************************************

tab ocup_padre_cat if muestra_padre==1

tab ocup_hijo if muestra_padre==1

tab movilidad_padre if muestra_padre==1

tab juntos if muestra_padre==1

tab urbano if muestra_padre==1

tab indigena if muestra_padre==1

tab hombre if muestra_padre==1


****************************************************
* 6.3 Estadísticas por participación en Juntos
****************************************************

tabstat ///
wi_r1 ///
tam_hogar_r1 ///
edad_r7, ///
by(juntos) ///
statistics(mean sd min max n)


tab educ_padre_ord juntos, row chi2

tab educ_madre_ord juntos, row chi2

tab urbano juntos, row chi2

tab hombre juntos, row chi2

****************************************************
* 6.4 Diferencia de medias
****************************************************

foreach x in wi_r1 tam_hogar_r1 edad_r7 {

    display "======================================"
    display "Variable: `x'"
    display "======================================"

    ttest `x', by(juntos)

}

****************************************************
* 6.5 Gráficos
****************************************************


histogram wi_r1 if muestra_padre==1, ///
percent normal ///
title("Índice de riqueza")


graph export ///
"$output\hist_riqueza.png", replace




graph bar (mean) ascendente_padre ///
if muestra_padre==1, ///
over(juntos) ///
title("Movilidad ascendente y Programa Juntos")


graph export ///
"$output\movilidad_juntos.png", replace

graph bar (mean) educ_superior ///
if muestra_padre==1, ///
over(juntos)


graph export ///
"$output\educ_superior.png", replace



log close

*===========================================================================
* PARTE 7: MOVILIDAD INTERGENERACIONAL
*===========================================================================

capture log close
log using "$output\movilidad_intergeneracional.log", replace


display "====================================================================="
display "MOVILIDAD INTERGENERACIONAL PADRE-HIJO"
display "====================================================================="


/*---------------------------------------------------------------------------
7.1 MATRIZ DE TRANSICIÓN PADRE-HIJO
---------------------------------------------------------------------------*/

tab ocup_padre_cat ocup_hijo ///
if muestra_padre==1, row chi2



/*---------------------------------------------------------------------------
7.2 MOVILIDAD ASCENDENTE
---------------------------------------------------------------------------*/

display _newline "====================================================================="
display "MOVILIDAD ASCENDENTE"
display "====================================================================="

tab ascendente_padre juntos ///
if muestra_padre==1, row chi2

prtest ascendente_padre ///
if muestra_padre==1, by(juntos)



/*---------------------------------------------------------------------------
7.3 MOVILIDAD DESCENDENTE
---------------------------------------------------------------------------*/

display _newline "====================================================================="
display "MOVILIDAD DESCENDENTE"
display "====================================================================="

tab descendente_padre juntos ///
if muestra_padre==1, row chi2

prtest descendente_padre ///
if muestra_padre==1, by(juntos)



/*---------------------------------------------------------------------------
7.4 INMOVILIDAD
---------------------------------------------------------------------------*/

display _newline "====================================================================="
display "INMOVILIDAD"
display "====================================================================="

tab inmovil_padre juntos ///
if muestra_padre==1, row chi2

prtest inmovil_padre ///
if muestra_padre==1, by(juntos)



/*---------------------------------------------------------------------------
7.5 ÍNDICE DE BARTHOLOMEW
---------------------------------------------------------------------------*/

capture drop distancia_padre
capture drop distancia_madre


gen distancia_padre = abs(ocup_hijo-ocup_padre_cat) ///
if muestra_padre==1


gen distancia_madre = abs(ocup_hijo-ocup_madre_cat) ///
if muestra_madre==1



label variable distancia_padre ///
"Distancia ocupacional respecto al padre"

label variable distancia_madre ///
"Distancia ocupacional respecto a la madre"



display _newline "====================================================================="
display "ÍNDICE DE BARTHOLOMEW PADRE-HIJO"
display "====================================================================="


display "Muestra total"

summ distancia_padre ///
if muestra_padre==1



display _newline "Beneficiarios Juntos"

summ distancia_padre ///
if muestra_padre==1 & juntos==1



display _newline "No beneficiarios"

summ distancia_padre ///
if muestra_padre==1 & juntos==0



display _newline "Prueba de diferencia de medias"

ttest distancia_padre ///
if muestra_padre==1, by(juntos)




display _newline "====================================================================="
display "ÍNDICE DE BARTHOLOMEW MADRE-HIJO"
display "====================================================================="


display "Muestra total"

summ distancia_madre ///
if muestra_madre==1



display _newline "Beneficiarios Juntos"

summ distancia_madre ///
if muestra_madre==1 & juntos==1



display _newline "No beneficiarios"

summ distancia_madre ///
if muestra_madre==1 & juntos==0



display _newline "Prueba de diferencia de medias"

ttest distancia_madre ///
if muestra_madre==1, by(juntos)



/*---------------------------------------------------------------------------
7.6 MOVILIDAD NETA
---------------------------------------------------------------------------*/

capture drop movilidad_neta_padre
capture drop movilidad_neta_madre


gen movilidad_neta_padre = ///
ocup_hijo-ocup_padre_cat ///
if muestra_padre==1


gen movilidad_neta_madre = ///
ocup_hijo-ocup_madre_cat ///
if muestra_madre==1



label variable movilidad_neta_padre ///
"Movilidad neta respecto al padre"

label variable movilidad_neta_madre ///
"Movilidad neta respecto a la madre"



display _newline "====================================================================="
display "MOVILIDAD NETA PADRE-HIJO"
display "====================================================================="

summ movilidad_neta_padre ///
if muestra_padre==1


ttest movilidad_neta_padre ///
if muestra_padre==1, by(juntos)




display _newline "====================================================================="
display "MOVILIDAD NETA MADRE-HIJO"
display "====================================================================="

summ movilidad_neta_madre ///
if muestra_madre==1


ttest movilidad_neta_madre ///
if muestra_madre==1, by(juntos)




/*---------------------------------------------------------------------------
7.7 GRÁFICOS
---------------------------------------------------------------------------*/

graph bar (mean) ascendente_padre ///
if muestra_padre==1, ///
over(juntos) ///
blabel(bar) ///
title("Movilidad ascendente") ///
ytitle("Proporción")

graph export ///
"$output\movilidad_ascendente_padre.png", replace



graph bar (mean) distancia_padre ///
if muestra_padre==1, ///
over(juntos) ///
blabel(bar) ///
title("Distancia promedio de movilidad") ///
ytitle("Número de categorías")

graph export ///
"$output\bartholomew_padre.png", replace



graph bar (mean) movilidad_neta_padre ///
if muestra_padre==1, ///
over(juntos) ///
blabel(bar) ///
title("Movilidad neta promedio") ///
ytitle("Cambio de categoría")

graph export ///
"$output\movilidad_neta_padre.png", replace

/*---------------------------------------------------------------------------
7.8 ROBUSTEZ MADRE-HIJO
---------------------------------------------------------------------------*/

display _newline "====================================================================="
display "ROBUSTEZ MADRE-HIJO"
display "====================================================================="


tab ocup_madre_cat ocup_hijo ///
if muestra_madre==1, row chi2



log close

*===========================================================================
* PARTE 8: PROPENSITY SCORE MATCHING
*===========================================================================

capture log close
log using "$output\resultados_PSM.log", replace

use "$output\base_analitica.dta", clear


*-----------------------------------------------------------
* 8.1 Muestra de análisis
*-----------------------------------------------------------

keep if muestra_padre==1



*-----------------------------------------------------------
* 8.2 Variables continuas de movilidad
*-----------------------------------------------------------

capture drop distancia_padre
capture drop movilidad_neta_padre


gen distancia_padre = abs(ocup_hijo-ocup_padre_cat)

gen movilidad_neta_padre = ///
ocup_hijo-ocup_padre_cat


label variable distancia_padre ///
"Distancia ocupacional respecto al padre"

label variable movilidad_neta_padre ///
"Movilidad ocupacional neta respecto al padre"



*-----------------------------------------------------------
* 8.3 Propensity Score
*-----------------------------------------------------------

logit juntos ///
      wi_r1 ///
      tam_hogar_r1 ///
      urbano ///
      hombre

predict pscore, pr

sum pscore if juntos==1
sum pscore if juntos==0



*-----------------------------------------------------------
* 8.4 Soporte común
*-----------------------------------------------------------

twoway ///
(kdensity pscore if juntos==1) ///
(kdensity pscore if juntos==0), ///
legend(order(1 "Juntos" 2 "No Juntos")) ///
title("Distribución del Propensity Score") ///
xtitle("Propensity Score")


graph export ///
"$output\pscore.png", replace

*-----------------------------------------------------------
* 8.5 Radius Matching
*-----------------------------------------------------------

display "========================================"
display "RADIUS MATCHING"
display "========================================"



*** MOVILIDAD ASCENDENTE

psmatch2 juntos ///
wi_r1 ///
tam_hogar_r1 ///
urbano ///
hombre,   ///
outcome(ascendente_padre) ///
radius ///
caliper(0.05)

*** DISTANCIA OCUPACIONAL

psmatch2 juntos ///
wi_r1 ///
tam_hogar_r1 ///
urbano ///
hombre, ///
outcome(distancia_padre) ///
radius ///
caliper(0.05)

*** MOVILIDAD NETA

psmatch2 juntos ///
wi_r1 ///
tam_hogar_r1 ///
urbano ///
hombre, ///
outcome(movilidad_neta_padre) ///
radius ///
caliper(0.05)

*-----------------------------------------------------------
* 8.6 Balance de covariables
*-----------------------------------------------------------

pstest ///
wi_r1 ///
tam_hogar_r1 ///
urbano ///
hombre, ///
both graphh




*-----------------------------------------------------------
* 8.7 Kernel Matching
*-----------------------------------------------------------

display "========================================"
display "KERNEL MATCHING"
display "========================================"



*** MOVILIDAD ASCENDENTE

psmatch2 juntos ///
wi_r1 ///
tam_hogar_r1 ///
urbano ///
hombre ///
i.educ_padre_ord, ///
outcome(ascendente_padre) ///
kernel




*** DISTANCIA OCUPACIONAL

psmatch2 juntos ///
wi_r1 ///
tam_hogar_r1 ///
urbano ///
hombre ///
i.educ_padre_ord, ///
outcome(distancia_padre) ///
kernel




*** MOVILIDAD NETA

psmatch2 juntos ///
wi_r1 ///
tam_hogar_r1 ///
urbano ///
hombre ///
i.educ_padre_ord, ///
outcome(movilidad_neta_padre) ///
kernel


/*---------------------------------------------------------
8.8 RESUMEN DE EFECTOS ESTIMADOS
---------------------------------------------------------*/


display ""
display "========================================"

display "RESUMEN PSM"

display "========================================"

display ""
display "Radius Matching"


display "Movilidad ascendente"

display "ATT = 0.234"



display ""
display "Distancia ocupacional"

display "ATT = 0.757"
display ""
display "Movilidad neta"

display "ATT = 0.727"
display ""
display "Kernel Matching"



display ""
display "Movilidad ascendente"

display "ATT = 0.243"



display ""
display "Distancia ocupacional"

display "ATT = 0.771"



display ""
display "Movilidad neta"

display "ATT = 0.737"

*-----------------------------------------------------------
* 8.9 Estadísticas descriptivas
*-----------------------------------------------------------

display _newline
display "DISTANCIA OCUPACIONAL"


summ distancia_padre if juntos==1

summ distancia_padre if juntos==0


display _newline
display "MOVILIDAD NETA"


summ movilidad_neta_padre if juntos==1

summ movilidad_neta_padre if juntos==0




capture log close

*===========================================================================
* PARTE 9 : MODELOS DE MOVILIDAD INTERGENERACIONAL
*===========================================================================

capture log close

log using "$output\modelos_movilidad.log", replace text


use "$output\base_analitica.dta", clear

keep if muestra_padre==1



/*---------------------------------------------------------
9.1 DIAGNÓSTICOS PREVIOS
---------------------------------------------------------*/

display ""
display "==========================================="
display "DIAGNÓSTICOS PREVIOS"
display "==========================================="


tab edad_r7


tab educ_padre_ord


tab educ_padre_ord movilidad_padre, row




/*---------------------------------------------------------
9.2 MODELO PRINCIPAL
Ordered Logit
---------------------------------------------------------*/

display ""
display "==========================================="
display "MODELO 1"
display "ORDERED LOGIT"
display "==========================================="


ologit movilidad_padre ///
       i.juntos ///
       wi_r1 ///
       tam_hogar_r1 ///
       urbano ///
       hombre, ///
       vce(robust)


estimates store M1


display ""

display "Pseudo R2 = " e(r2_p)

display "Log likelihood = " e(ll)




/*---------------------------------------------------------
9.3 EFECTOS MARGINALES
---------------------------------------------------------*/


display ""

display "==========================================="

display "EFECTOS MARGINALES"

display "==========================================="


margins, dydx(juntos)




/*---------------------------------------------------------
9.4 MOVILIDAD ASCENDENTE
---------------------------------------------------------*/


margins juntos, ///
predict(outcome(3))


marginsplot, ///
title("Probabilidad de movilidad ascendente") ///
ytitle("Probabilidad") ///
xtitle("Programa Juntos") ///
name(fig1, replace)


graph export ///
"$output\movilidad_ascendente_ologit.png", replace




/*---------------------------------------------------------
9.5 ROBUSTEZ
Educación paterna
---------------------------------------------------------*/


display ""

display "==========================================="

display "MODELO 2"

display "ROBUSTEZ"

display "Educación del padre"

display "==========================================="


ologit movilidad_padre ///
       i.juntos ///
       wi_r1 ///
       tam_hogar_r1 ///
       urbano ///
       hombre ///
       i.educ_padre_ord, ///
       vce(robust)


estimates store M2




/*---------------------------------------------------------
9.6 ROBUSTEZ
Ocupación alcanzada
---------------------------------------------------------*/


display ""

display "==========================================="

display "MODELO 3"

display "OCUPACIÓN DEL HIJO"

display "==========================================="



ologit ocup_hijo ///
       i.juntos ///
       wi_r1 ///
       tam_hogar_r1 ///
       urbano ///
       hombre, ///
       vce(robust)


estimates store M3




margins juntos, ///
predict(outcome(4))


marginsplot, ///
title("Probabilidad de alcanzar ocupación profesional") ///
ytitle("Probabilidad") ///
xtitle("Programa Juntos") ///
name(fig2, replace)


graph export ///
"$output\ocupacion_profesional.png", replace





/*---------------------------------------------------------
9.7 ROBUSTEZ
MULTINOMIAL LOGIT
---------------------------------------------------------*/


display ""

display "==========================================="

display "MODELO 4"

display "MULTINOMIAL LOGIT"

display "==========================================="


mlogit movilidad_padre ///
       i.juntos ///
       wi_r1 ///
       tam_hogar_r1 ///
       urbano ///
       hombre, ///
       vce(robust)


estimates store M4





margins juntos, predict(outcome(1))


marginsplot, ///
title("Movilidad descendente") ///
ytitle("Probabilidad") ///
name(fig3, replace)


graph export ///
"$output\movilidad_descendente.png", replace





margins juntos, predict(outcome(2))


marginsplot, ///
title("Inmovilidad") ///
ytitle("Probabilidad") ///
name(fig4, replace)


graph export ///
"$output\inmovilidad.png", replace






margins juntos, predict(outcome(3))


marginsplot, ///
title("Movilidad ascendente") ///
ytitle("Probabilidad") ///
name(fig5, replace)


graph export ///
"$output\movilidad_ascendente_mlogit.png", replace




/*---------------------------------------------------------
9.8 COMPARACIÓN DE MODELOS
---------------------------------------------------------*/


display ""

display "==========================================="

display "COMPARACIÓN DE MODELOS"

display "==========================================="
estimates stats M1 M2 M3 M4

/*---------------------------------------------------------
9.9 EXPORTAR TABLA
---------------------------------------------------------*/

capture which esttab

if _rc {

ssc install estout, replace

}

esttab M1 M2 M3 M4 ///
using "$output\tabla_modelos.rtf", ///
replace ///
b(3) ///
se(3) ///
star(* 0.10 ** 0.05 *** 0.01) ///
stats(N ll r2_p)

capture log close

*===========================================================================
*  EXPORTACIÓN FINAL
*===========================================================================
use "$output\base_analitica.dta", clear
save "$output\base_final_analisis.dta", replace

display _newline "================================================================"
display " DO-FILE COMPLETADO"
display " Archivos generados en: $output"
display "  - base_longitudinal_completa.dta"
display "  - base_analitica.dta / base_final_analisis.dta"
display "  - diagnostico_missing.log"
display "  - descriptivos_completos.log"
display "  - matrices_markov.log"
display "  - resultados_PSM.log"
display "  - resultados_ologit.log"
display "  - tabla_ologit_madre.xls / _padre.xls / _conjunto.xls"
display "================================================================"

