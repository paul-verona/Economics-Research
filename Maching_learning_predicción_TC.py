"""
TEMA: Predicción del tipo de cambio en el Perú mediante machine learning
Metodología completa en Python

  Objetivo general: evaluar si el Random Forest mejora la precisión y la eficiencia del
      pronóstico del tipo de cambio PEN/USD frente a los métodos tradicionales
  Objetivo específico 1: identificar y seleccionar las variables relevantes
      disponibilidad -> redundancia -> Granger + LASSO + importancia por
      permutación del Random Forest (5 bloques) -> regla de consenso (>= 2 de 3)
  Objetivo específico 2: comparar el Random Forest con ARIMA, AR-GARCH(1,1) y modelos de
      regresión dinámica (VECM con cointegración de Johansen y regresión dinámica por MCO)
      pronóstico fuera de muestra con ventana expansiva, horizontes 1, 3, 6 y 12 meses
      métricas: RMSE, MAE y MAPE; además R2 fuera de muestra, Diebold-Mariano (HAC + HLN),
      Clark-West, acierto de dirección y Pesaran-Timmermann
      eficiencia: tiempo de estimación y pronóstico de cada modelo
  Referencias: paseo aleatorio (con y sin deriva); complementarios: VAR, XGBoost y combinado
  Extras: robustez con 3 semillas, SHAP y dependencia parcial

Uso:
    pip install pandas numpy scikit-learn statsmodels arch xgboost shap matplotlib requests yfinance
    python metodologia_tc_ml_final.py
    (o: python metodologia_tc_ml_final.py RUTA_BASE.xlsx CARPETA_RESULTADOS)
"""

import sys
import time
import warnings
from math import ceil, sqrt
from pathlib import Path

import numpy as np
import pandas as pd
import statsmodels.api as sm
from arch import arch_model
from scipy import stats
from sklearn.ensemble import RandomForestRegressor
from sklearn.inspection import PartialDependenceDisplay
from sklearn.linear_model import LassoCV, LinearRegression
from sklearn.model_selection import KFold
from statsmodels.tsa.api import VAR
from statsmodels.tsa.arima.model import ARIMA
from statsmodels.tsa.stattools import adfuller, kpss
from statsmodels.tsa.vector_ar.vecm import VECM, coint_johansen
from xgboost import XGBRegressor

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

warnings.filterwarnings("ignore")

# ----------------------------------------------------------------------------
# 0. CONFIGURACIÓN
# ----------------------------------------------------------------------------
DIR = Path("C:/Users/Paul/Documents/base_date_ml")
BASE = DIR / "BASE_DE_DATOS_-_R3.xlsx"
OUT = DIR / "RESULTADOS_PYTHON"
if len(sys.argv) >= 3:
    BASE, OUT = Path(sys.argv[1]), Path(sys.argv[2])
OUT.mkdir(parents=True, exist_ok=True)

INI, TEST_INI, FIN = pd.Period("2007-02", "M"), pd.Period("2021-01", "M"), pd.Period("2025-12", "M")
HORIZ = [1, 3, 6, 12]
NTREE = 300
NPERM = 10
CORR_MAX = 0.90
P_GRANGER = 0.10
VOTOS_MIN = 2
SEMILLAS = [123, 456, 789]
SEED = 123

# Paleta categórica (orden fijo) y estilo sobrio de figuras
COL = {"real": "#1f1f1f", "rf": "#2a78d6", "xgb": "#eb6834", "arima": "#1baf7a",
       "combo": "#eda100", "var": "#e87ba4", "ols": "#008300", "rw": "#8a8a85"}
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 10, "axes.spines.top": False,
                     "axes.spines.right": False, "axes.grid": True, "grid.color": "#e6e6e3",
                     "grid.linewidth": 0.6, "axes.edgecolor": "#8a8a85", "lines.linewidth": 2})

T_START = time.time()
LOG = []


def log(msg=""):
    print(msg)
    LOG.append(str(msg))


# ----------------------------------------------------------------------------
# 1. IMPORTACIÓN Y PREPARACIÓN
# ----------------------------------------------------------------------------
NOMBRES = ("fecha tc infl_pe rin_base cobre dxy overnight interb_me_base tasa_ref interb_mn "
           "interb_me tipmn tipmex embig ti expo impo oro wti pbi_ind rin dolariz tc_esp "
           "sol_usd sol_clp compras ust10 fed vix cpi_us dif_tasa_fed dif_pasivas saldo clp "
           "infl_us pbi_var d_elec d_cpol d_c2008 d_covid d_afp dif_infl").split()
df = pd.read_excel(BASE, sheet_name="DATOS", header=None, skiprows=1)
df.columns = NOMBRES
df.index = pd.PeriodIndex(df.pop("fecha").astype(str), freq="M")
df = df.apply(pd.to_numeric, errors="coerce")
DUMMIES_BASE = ["d_elec", "d_cpol", "d_c2008", "d_covid", "d_afp"]
print(f"Base leída: {BASE.name} | {df.index.min()} a {df.index.max()} | {len(df)} meses")

# Oct-2025: el BLS no publicó el CPI (cierre del gobierno de EE. UU.) -> interpolación
for v in ["infl_us", "dif_infl"]:
    df[v] = df[v].interpolate()
# Columnas de la base original que fueron corregidas
df = df.drop(columns=["overnight", "interb_me_base", "rin_base", "sol_usd", "sol_clp", "pbi_ind", "cpi_us"])

# Series oficiales verificadas que reemplazan columnas de la base original cuyo origen
# no estaba documentado. Si no hay conexión, se conserva la columna original y se avisa.
#   tc    : BCRP PN01207PM, tipo de cambio interbancario promedio, promedio del periodo
#   cobre : BCRP PN01652XM, cobre LME, promedio del periodo (centavos US$/lb -> US$/lb)
#   dxy   : ICE U.S. Dollar Index (DX-Y.NYB, vía Yahoo Finance), promedio del cierre diario
#   infl_pe corresponde a BCRP PN01273PM (IPC Lima Metropolitana, var. % 12 meses)
import json
import requests

MESES = {"ene": 1, "feb": 2, "mar": 3, "abr": 4, "may": 5, "jun": 6, "jul": 7, "ago": 8,
         "sep": 9, "set": 9, "oct": 10, "nov": 11, "dic": 12}


def bcrp_mensual(cod, ini="2003-1", fin="2025-12", intentos=3):
    url = f"https://estadisticas.bcrp.gob.pe/estadisticas/series/api/{cod}/json/{ini}/{fin}"
    for k in range(intentos):
        try:
            resp = requests.get(url, headers={"User-Agent": "Mozilla/5.0"}, timeout=60)
            resp.raise_for_status()
            data = json.loads(resp.content.decode("utf-8-sig"))
            break
        except Exception:  # noqa: BLE001
            if k == intentos - 1:
                raise
            time.sleep(3)
    out = {}
    for per_ in data["periods"]:
        mes, anio = per_["name"].split(".")
        try:
            out[pd.Period(year=int(anio), month=MESES[mes[:3].lower()], freq="M")] = float(per_["values"][0])
        except (ValueError, KeyError):
            pass
    s_ = pd.Series(out, dtype=float)
    s_.index = pd.PeriodIndex(s_.index, freq="M")
    return s_


# Ventana que debe quedar completa (incluye 13 meses previos al inicio por rezagos y diferencias)
VENT = (df.index >= INI - 13) & (df.index <= FIN)


def reemplazar(col, serie, etiqueta):
    """Reemplaza la columna solo si la serie oficial cubre toda la ventana de estimación."""
    serie.index = pd.PeriodIndex(serie.index, freq="M")
    al = serie.reindex(df.index)
    faltan = int(al[VENT].isna().sum())
    if faltan > 0:
        raise ValueError(f"descargada ({len(serie)} meses, {serie.index.min()} a {serie.index.max()}) "
                         f"pero faltan {faltan} meses de la ventana")
    df.loc[VENT, col] = al[VENT].values
    FUENTE[col] = etiqueta


FUENTE = {}
for col, cod, escala in [("tc", "PN01207PM", 1.0), ("cobre", "PN01652XM", 100.0)]:
    try:
        reemplazar(col, bcrp_mensual(cod) / escala, f"BCRP {cod}")
    except Exception as e:  # noqa: BLE001
        FUENTE[col] = f"base original (no se pudo usar {cod}: {e})"
try:
    import yfinance as yf
    dx = yf.download("DX-Y.NYB", start="2005-01-01", end="2026-01-01", progress=False, auto_adjust=False)
    dx = dx["Close"]
    if isinstance(dx, pd.DataFrame):
        dx = dx.iloc[:, 0]
    dx = dx.dropna()
    if len(dx) == 0:
        raise ValueError("Yahoo Finance no devolvió datos")
    dx.index = pd.to_datetime(dx.index).tz_localize(None) if getattr(dx.index, "tz", None) else pd.to_datetime(dx.index)
    reemplazar("dxy", dx.groupby(dx.index.to_period("M")).mean(), "ICE U.S. Dollar Index (Yahoo Finance, DX-Y.NYB)")
except Exception as e:  # noqa: BLE001
    FUENTE["dxy"] = f"base original (no se pudo usar el DXY: {e})"
for k_, v_ in FUENTE.items():
    print(f"Fuente de {k_}: {v_}")

# Control de datos faltantes en la ventana de estimación
VENT2 = (df.index >= INI - 2) & (df.index <= FIN)
falt = df.loc[VENT2].drop(columns=DUMMIES_BASE, errors="ignore").isna().sum()
falt = falt[falt > 0]
if len(falt):
    print("\nATENCIÓN: datos faltantes entre", INI - 2, "y", FIN, "en la base:")
    for c_, n_ in falt.items():
        meses_ = df.index[VENT2 & df[c_].isna().values]
        print(f"   {c_}: {n_} meses (p. ej. {', '.join(str(m) for m in meses_[:6])})")
    if "tc" in falt.index:
        sys.exit("El tipo de cambio tiene meses vacíos: complete la columna tc en la base y vuelva a correr.")
    print("Estas variables quedarán fuera por el filtro de disponibilidad.\n")

# ----------------------------------------------------------------------------
# 2. TRANSFORMACIONES Y REZAGOS DE PUBLICACIÓN
# ----------------------------------------------------------------------------
df["r"] = 100 * np.log(df.tc / df.tc.shift(1))          # retorno log. mensual (%)
df["ln_tc"] = np.log(df.tc)
z = pd.DataFrame(index=df.index)
for v in "tasa_ref interb_mn tipmn tipmex dif_pasivas fed dif_tasa_fed ust10 embig vix dolariz saldo".split():
    z[v] = df[v].diff()                                   # tasas y spreads: primera diferencia
for v in "dxy cobre oro wti clp rin ti expo impo".split():
    z[v] = 100 * np.log(df[v]).diff()                     # precios y montos: variación log. (%)
z["infl_pe"], z["infl_us"], z["dif_infl"], z["pbi"] = df.infl_pe, df.infl_us, df.dif_infl, df.pbi_var
z["compras"] = df.compras / 1000
z["dep_esp"] = (100 * np.log(df.tc_esp / df.tc)).diff()

GRUPO_A = ("tasa_ref interb_mn tipmn tipmex dif_pasivas fed dif_tasa_fed ust10 embig vix dxy "
           "cobre oro wti clp rin compras infl_pe dif_infl dep_esp").split()   # rezago 1
GRUPO_B = "saldo expo impo ti dolariz infl_us".split()                         # rezago 2
GRUPO_C = ["pbi"]                                                               # rezago 3
DUMMIES = "d_elec d_cpol d_c2008 d_covid d_afp".split()

X = pd.DataFrame(index=df.index)
for v in GRUPO_A:
    X[v] = z[v].shift(1)
for v in GRUPO_B:
    X[v] = z[v].shift(2)
for v in GRUPO_C:
    X[v] = z[v].shift(3)
for d in DUMMIES:
    X[d] = df[d].shift(1)
AR = ["r1", "r2", "r3"]
for k in (1, 2, 3):
    X[f"r{k}"] = df.r.shift(k)

per = df.index
muestra = (per >= INI) & (per <= FIN)
train = (per >= INI) & (per < TEST_INI)
test = (per >= TEST_INI) & (per <= FIN)
pos = {p: i for i, p in enumerate(per)}
i_ini, i_test, i_fin = pos[INI], pos[TEST_INI], pos[FIN]
r = df.r.values

log(f"Muestra: {INI} a {FIN} | entrenamiento hasta {TEST_INI - 1} ({train.sum()} meses) | prueba {test.sum()} meses")

# ----------------------------------------------------------------------------
# 3. PRUEBAS DE RAÍZ UNITARIA (entrenamiento)
# ----------------------------------------------------------------------------
filas = []
series_ur = {"r": df.r, "ln_tc": df.ln_tc, **{f"z_{v}": z[v] for v in GRUPO_A + GRUPO_B + GRUPO_C}}
for nombre, s in series_ur.items():
    s = s[train].dropna()
    adf = adfuller(s, maxlag=2, autolag=None, regression="c")
    kp = kpss(s, regression="c", nlags=4)
    filas.append([nombre, adf[0], adf[1], kp[0], kp[1]])
UR = pd.DataFrame(filas, columns=["serie", "ADF_estad", "ADF_p", "KPSS_estad", "KPSS_p"]).set_index("serie")
log("\nRaíz unitaria (ADF H0: raíz unitaria | KPSS H0: estacionaria)")
log(UR.round(3).to_string())

# ----------------------------------------------------------------------------
# 4. OBJETIVO 1: SELECCIÓN DE VARIABLES (solo entrenamiento)
# ----------------------------------------------------------------------------
CAND0 = GRUPO_A + GRUPO_B + GRUPO_C + DUMMIES
ok_rows = train | test
CAND = [c for c in CAND0 if X.loc[ok_rows, c].notna().all()]
DESC_DISP = [c for c in CAND0 if c not in CAND]

# 4.2 Redundancia
Xtr = X.loc[train]
rtr = df.r[train]
desc_corr = []
for i, a in enumerate(CAND):
    if a in desc_corr:
        continue
    for b in CAND[i + 1:]:
        if b in desc_corr:
            continue
        rho = Xtr[a].corr(Xtr[b])
        if pd.notna(rho) and abs(rho) > CORR_MAX:
            ra, rb = abs(rtr.corr(Xtr[a])), abs(rtr.corr(Xtr[b]))
            desc_corr.append(b if ra >= rb else a)
CAND_F = [c for c in CAND if c not in desc_corr]
log(f"\n4.1 Descartadas por disponibilidad: {DESC_DISP}")
log(f"4.2 Descartadas por redundancia: {desc_corr}")

SEL = pd.DataFrame(index=CAND_F, columns=["granger_p", "granger", "lasso", "rf_import",
                                          "rf_bloques", "rf", "votos"], dtype=float)

# 4.3 Granger: ¿x aporta a predecir r, dado el pasado de r?
for c in CAND_F:
    Z = sm.add_constant(Xtr[AR + [c]])
    fit = sm.OLS(rtr, Z).fit(cov_type="HC1")
    SEL.loc[c, "granger_p"] = fit.pvalues[c]
SEL["granger"] = (SEL.granger_p < P_GRANGER).astype(int)

# 4.4 LASSO con validación cruzada; los rezagos AR quedan sin penalizar
#     (Frisch-Waugh: se descuenta su efecto de r y de cada candidata)
A = sm.add_constant(Xtr[AR]).values
proj = A @ np.linalg.pinv(A)
r_res = rtr.values - proj @ rtr.values
C_res = Xtr[CAND_F].values - proj @ Xtr[CAND_F].values
sd = C_res.std(axis=0)
sd[sd == 0] = 1
lasso = LassoCV(cv=KFold(5, shuffle=True, random_state=SEED), random_state=SEED, max_iter=50000)
lasso.fit(C_res / sd, r_res)
SEL["lasso"] = (np.abs(lasso.coef_) > 1e-8).astype(int)

# 4.5 Importancia por permutación en 5 bloques de 12 meses
rng = np.random.default_rng(SEED)
feats = AR + CAND_F
nv = ceil(len(feats) / 3)
IMPF = pd.DataFrame(index=CAND_F, columns=range(1, 6), dtype=float)
for f in range(1, 6):
    v0 = i_test - 12 * (6 - f)
    fit_idx = np.arange(i_ini, v0)
    val_idx = np.arange(v0, v0 + 12)
    rf = RandomForestRegressor(n_estimators=NTREE, max_features=nv, random_state=SEED, n_jobs=-1)
    rf.fit(X.iloc[fit_idx][feats], r[fit_idx])
    Xv = X.iloc[val_idx][feats].copy()
    mse0 = np.mean((r[val_idx] - rf.predict(Xv)) ** 2)
    for c in CAND_F:
        inc = []
        for _ in range(NPERM):
            Xp = Xv.copy()
            Xp[c] = rng.permutation(Xp[c].values)
            inc.append(np.mean((r[val_idx] - rf.predict(Xp)) ** 2) - mse0)
        IMPF.loc[c, f] = np.mean(inc)
SEL["rf_import"] = IMPF.mean(axis=1)
SEL["rf_bloques"] = (IMPF > 0).sum(axis=1)
SEL["rf"] = ((SEL.rf_import > 0) & (SEL.rf_bloques >= 3)).astype(int)

# 4.6 Regla de consenso
SEL["votos"] = SEL.granger + SEL.lasso + SEL.rf
XSEL = SEL.index[SEL.votos >= VOTOS_MIN].tolist()
log("\nObjetivo 1: tabla de selección")
log(SEL.round(4).to_string())
log(f"\nVARIABLES SELECCIONADAS: {XSEL}")

# ----------------------------------------------------------------------------
# 5. OBJETIVO 2: ESPECIFICACIÓN DE LOS MODELOS (entrenamiento)
# ----------------------------------------------------------------------------
espec = []
r_tr = df.r[train].values

# 5.1 ARIMA(p,0,q) por BIC
best = (np.inf, 0, 0)
for p_ in range(4):
    for q_ in range(4):
        try:
            m = ARIMA(r_tr, order=(p_, 0, q_), trend="c").fit()
            if m.bic < best[0]:
                best = (m.bic, p_, q_)
        except Exception:
            pass
P, Q = best[1], best[2]
m_arima = ARIMA(r_tr, order=(P, 0, Q), trend="c").fit()
espec.append(f"ARIMA elegido por BIC: ARIMA({P},0,{Q})\n{m_arima.summary()}")
log(f"\nARIMA elegido por BIC: ARIMA({P},0,{Q})")

# 5.2 AR(1)-GARCH(1,1)
m_garch = arch_model(r_tr, mean="AR", lags=1, vol="GARCH", p=1, q=1, rescale=False).fit(disp="off")
espec.append(f"AR(1)-GARCH(1,1)\n{m_garch.summary()}")

# 5.3 VAR: r + 3 variables de mercado (grupo A) con menor p de Granger
cand_A = SEL.loc[[c for c in CAND_F if c in GRUPO_A]].sort_values("granger_p")
VAR_VARS = cand_A.index[:3].tolist()
var_df = pd.concat([df.r, z[VAR_VARS]], axis=1)
var_df.columns = ["r"] + VAR_VARS
sel_ord = VAR(var_df[train].values).select_order(maxlags=6)
PVAR = max(1, int(sel_ord.bic))
m_var = VAR(var_df[train].values).fit(PVAR)
espec.append(f"VAR con r + {VAR_VARS}, rezagos (BIC) = {PVAR}\n{m_var.summary()}")
log(f"VAR con r + {VAR_VARS} | rezagos (BIC): {PVAR}")

# 5.4 Johansen -> VECM
lvl = pd.DataFrame({"ln_tc": df.ln_tc, "ln_dxy": np.log(df.dxy), "ln_rin": np.log(df.rin),
                    "ln_cobre": np.log(df.cobre)})
jo = coint_johansen(lvl[train].values, det_order=0, k_ar_diff=1)
RANGO = 0
for k in range(lvl.shape[1]):
    if jo.lr1[k] > jo.cvt[k, 1]:
        RANGO = k + 1
    else:
        break
JOH = pd.DataFrame({"rango_H0": range(lvl.shape[1]), "traza": jo.lr1, "critico_5%": jo.cvt[:, 1]})
log("\nJohansen (traza):\n" + JOH.round(3).to_string(index=False))
log(f"Rango de cointegración: {RANGO}")
if RANGO > 0:
    m_vecm = VECM(lvl[train].values, k_ar_diff=1, coint_rank=RANGO, deterministic="co").fit()
    espec.append(f"VECM rango {RANGO}\n{m_vecm.summary()}")

# 5.5 Hiperparámetros por validación cruzada temporal (5 bloques de 12 meses, h = 1)
XRF = AR + XSEL


def cv_bloques(make_model):
    sse, n = 0.0, 0
    for f in range(1, 6):
        v0 = i_test - 12 * (6 - f)
        tr, va = np.arange(i_ini, v0), np.arange(v0, v0 + 12)
        mdl = make_model()
        mdl.fit(X.iloc[tr][XRF], r[tr])
        sse += np.sum((r[va] - mdl.predict(X.iloc[va][XRF])) ** 2)
        n += len(va)
    return sqrt(sse / n)


pfe = len(XRF)
grid_rf = []
for nvv in sorted({2, ceil(sqrt(pfe)), ceil(pfe / 3)}):
    for dp in [None, 6]:
        for ls in [1, 5]:
            rmse = cv_bloques(lambda: RandomForestRegressor(n_estimators=NTREE, max_features=nvv, max_depth=dp,
                                                            min_samples_leaf=ls, random_state=SEED, n_jobs=-1))
            grid_rf.append([nvv, dp if dp else 0, ls, rmse])
GRID_RF = pd.DataFrame(grid_rf, columns=["max_features", "max_depth(0=sin límite)", "min_samples_leaf", "RMSE_CV"])
b = GRID_RF.RMSE_CV.idxmin()
RF_PAR = dict(max_features=int(GRID_RF.iloc[b, 0]), max_depth=(None if GRID_RF.iloc[b, 1] == 0 else int(GRID_RF.iloc[b, 1])),
              min_samples_leaf=int(GRID_RF.iloc[b, 2]))
log(f"\nRandom Forest elegido: {RF_PAR}")

grid_x = []
for dp in [2, 3]:
    for ne in [100, 300]:
        for lr in [0.03, 0.1]:
            rmse = cv_bloques(lambda: XGBRegressor(n_estimators=ne, learning_rate=lr, max_depth=dp, min_child_weight=5,
                                                   subsample=0.8, colsample_bytree=0.8, random_state=SEED, n_jobs=4))
            grid_x.append([dp, ne, lr, rmse])
GRID_X = pd.DataFrame(grid_x, columns=["max_depth", "n_estimators", "learning_rate", "RMSE_CV"])
b = GRID_X.RMSE_CV.idxmin()
XGB_PAR = dict(max_depth=int(GRID_X.iloc[b, 0]), n_estimators=int(GRID_X.iloc[b, 1]),
               learning_rate=float(GRID_X.iloc[b, 2]), min_child_weight=5, subsample=0.8, colsample_bytree=0.8)
log(f"XGBoost elegido: {XGB_PAR}")


def nuevo_rf(seed=SEED):
    return RandomForestRegressor(n_estimators=NTREE, random_state=seed, n_jobs=-1, **RF_PAR)


def nuevo_xgb(seed=SEED):
    return XGBRegressor(random_state=seed, n_jobs=4, **XGB_PAR)


# ----------------------------------------------------------------------------
# 6. PRONÓSTICO FUERA DE MUESTRA (ventana expansiva, reestimación mensual)
#    Objetivo a h meses: y_h(t) = 100*[ln TC(t+h-1) - ln TC(t-1)], pronosticado al
#    inicio de t. Los modelos directos se entrenan con t <= T-h (objetivo ya conocido).
# ----------------------------------------------------------------------------
MODELOS = ["rw", "drift", "arima", "garch", "var", "vecm", "ols", "rf", "xgb", "combo"]
ln_tc = df.ln_tc.values
Y = {h: 100 * (pd.Series(ln_tc, index=per).shift(-(h - 1)) - pd.Series(ln_tc, index=per).shift(1)).values for h in HORIZ}
F = {h: pd.DataFrame(np.nan, index=per, columns=MODELOS) for h in HORIZ}
hmax = max(HORIZ)
log("\nPronosticando...")
# Eficiencia: segundos de estimación + pronóstico de cada modelo en cada origen (todos los horizontes)
TIEMPO = {m: 0.0 for m in MODELOS if m != "combo"}
N_ORIG = 0
reloj = time.perf_counter
for T in range(i_test, i_fin + 1):
    N_ORIG += 1
    hs = [h for h in HORIZ if T + h - 1 <= i_fin]
    H = max(hs)
    hist = r[i_ini:T]
    t0 = reloj()
    for h in hs:
        F[h].iloc[T, MODELOS.index("rw")] = 0.0
    TIEMPO["rw"] += reloj() - t0
    t0 = reloj()
    for h in hs:
        F[h].iloc[T, MODELOS.index("drift")] = h * hist.mean()
    TIEMPO["drift"] += reloj() - t0
    # ARIMA
    t0 = reloj()
    try:
        fc = ARIMA(hist, order=(P, 0, Q), trend="c").fit().forecast(H)
        for h in hs:
            F[h].iloc[T, MODELOS.index("arima")] = fc[:h].sum()
    except Exception:
        pass
    TIEMPO["arima"] += reloj() - t0
    # AR(1)-GARCH(1,1)
    t0 = reloj()
    try:
        g = arch_model(hist, mean="AR", lags=1, vol="GARCH", p=1, q=1, rescale=False).fit(disp="off")
        gm = g.forecast(horizon=H, reindex=False).mean.values[-1]
        for h in hs:
            F[h].iloc[T, MODELOS.index("garch")] = gm[:h].sum()
    except Exception:
        pass
    TIEMPO["garch"] += reloj() - t0
    # VAR
    t0 = reloj()
    try:
        vd = var_df.values[i_ini:T]
        vm = VAR(vd).fit(PVAR)
        vf = vm.forecast(vd[-PVAR:], steps=H)[:, 0]
        for h in hs:
            F[h].iloc[T, MODELOS.index("var")] = vf[:h].sum()
    except Exception:
        pass
    TIEMPO["var"] += reloj() - t0
    # VECM
    t0 = reloj()
    if RANGO > 0:
        try:
            ld = lvl.values[i_ini:T]
            vp = VECM(ld, k_ar_diff=1, coint_rank=RANGO, deterministic="co").fit().predict(steps=H)[:, 0]
            for h in hs:
                F[h].iloc[T, MODELOS.index("vecm")] = 100 * (vp[h - 1] - ln_tc[T - 1])
        except Exception:
            pass
    TIEMPO["vecm"] += reloj() - t0
    # Modelos directos: MCO, Random Forest y XGBoost (un modelo por horizonte)
    for h in hs:
        tr = np.arange(i_ini, T - h + 1)
        Xt, yt = X.iloc[tr][XRF], Y[h][tr]
        xT = X.iloc[[T]][XRF]
        t0 = reloj()
        F[h].iloc[T, MODELOS.index("ols")] = LinearRegression().fit(Xt, yt).predict(xT)[0]
        TIEMPO["ols"] += reloj() - t0
        t0 = reloj()
        F[h].iloc[T, MODELOS.index("rf")] = nuevo_rf().fit(Xt, yt).predict(xT)[0]
        TIEMPO["rf"] += reloj() - t0
        t0 = reloj()
        F[h].iloc[T, MODELOS.index("xgb")] = nuevo_xgb().fit(Xt, yt).predict(xT)[0]
        TIEMPO["xgb"] += reloj() - t0
    if (T - i_test) % 12 == 0:
        log(f"  origen {per[T]} listo ({time.time() - T_START:.0f} s)")

for h in HORIZ:
    F[h]["combo"] = F[h][["arima", "garch", "var", "vecm", "ols", "rf", "xgb"]].mean(axis=1)


# ----------------------------------------------------------------------------
# 7. MÉTRICAS
# ----------------------------------------------------------------------------
def dm_hln(e1, e2, h):
    """Diebold-Mariano (pérdida cuadrática), HAC con h-1 rezagos, corrección HLN."""
    d = e1 ** 2 - e2 ** 2
    d = d[~np.isnan(d)]
    n = len(d)
    if n < 10 or d.std() == 0:
        return np.nan
    fit = sm.OLS(d, np.ones(n)).fit(cov_type="HAC", cov_kwds={"maxlags": h - 1})
    stat = fit.tvalues[0] * sqrt((n + 1 - 2 * h + h * (h - 1) / n) / n)
    return 2 * stats.t.sf(abs(stat), n - 1)


def clark_west(y, f, h):
    """Clark y West (2007): modelo frente al paseo aleatorio (anidado, pronóstico 0).
    H0: igual precisión; H1: el modelo es más preciso. p-valor unilateral, HAC con h-1 rezagos."""
    m = ~np.isnan(y) & ~np.isnan(f)
    y, f = y[m], f[m]
    adj = y ** 2 - ((y - f) ** 2 - f ** 2)
    n = len(adj)
    if n < 10 or adj.std() == 0:
        return np.nan
    fit = sm.OLS(adj, np.ones(n)).fit(cov_type="HAC", cov_kwds={"maxlags": h - 1})
    return 1 - stats.norm.cdf(fit.tvalues[0])


def pesaran_timmermann(y, f):
    """Acierto de dirección y p-valor unilateral de Pesaran-Timmermann (1992)."""
    m = ~np.isnan(y) & ~np.isnan(f)
    a, b = (y[m] > 0).astype(float), (f[m] > 0).astype(float)
    n = len(a)
    P = np.mean(a == b)
    py, px = a.mean(), b.mean()
    ps = py * px + (1 - py) * (1 - px)
    vp = ps * (1 - ps) / n
    vps = ((2 * py - 1) ** 2 * px * (1 - px) + (2 * px - 1) ** 2 * py * (1 - py)) / n + 4 * py * px * (1 - py) * (1 - px) / n ** 2
    p = 1 - stats.norm.cdf((P - ps) / sqrt(vp - vps)) if vp - vps > 0 else np.nan
    return P, p


MET, R2H = {}, pd.DataFrame(index=MODELOS, columns=[f"h{h}" for h in HORIZ], dtype=float)
tc = df.tc.values
for h in HORIZ:
    idx = np.arange(i_test, i_fin - h + 2)
    y = Y[h][idx]
    tc_prev, tc_fin = tc[idx - 1], tc[idx + h - 1]
    e_rw = y - F[h]["rw"].values[idx]
    rows = []
    for m in MODELOS:
        f = F[h][m].values[idx]
        e = y - f
        lvl_err = tc_fin - tc_prev * np.exp(f / 100)
        r2 = 1 - np.nansum(e ** 2) / np.nansum(e_rw ** 2)
        dm = dm_hln(e, e_rw, h) if m != "rw" else np.nan
        cw = clark_west(y, f, h) if m != "rw" else np.nan
        hit, pt = pesaran_timmermann(y, f) if m != "rw" else (np.nan, np.nan)
        rows.append([sqrt(np.nanmean(e ** 2)), np.nanmean(np.abs(e)), sqrt(np.nanmean(lvl_err ** 2)),
                     100 * np.nanmean(np.abs(lvl_err) / tc_fin), r2, dm, cw, hit, pt])
        R2H.loc[m, f"h{h}"] = r2
    MET[h] = pd.DataFrame(rows, index=MODELOS, columns=["RMSE_ret", "MAE_ret", "RMSE_nivel", "MAPE_pct",
                                                        "R2_oos", "DM_vs_RW_p", "CW_p", "Acierto_dir", "PT_p"])
    log(f"\nDesempeño fuera de muestra - h = {h} meses ({len(idx)} pronósticos)")
    log(MET[h].round(4).to_string())
log("\nR2 fuera de muestra frente al paseo aleatorio:")
log(R2H.round(4).to_string())

# Eficiencia: costo computacional y precisión relativa (h = 1)
import os
import platform
EFI = pd.DataFrame({"tiempo_total_s": pd.Series(TIEMPO)})
EFI["tiempo_medio_por_origen_s"] = EFI.tiempo_total_s / N_ORIG
EFI["veces_tiempo_ARIMA"] = EFI.tiempo_total_s / EFI.loc["arima", "tiempo_total_s"]
EFI["RMSE_nivel_h1"] = MET[1].loc[EFI.index, "RMSE_nivel"]
EFI["R2_oos_h1"] = MET[1].loc[EFI.index, "R2_oos"]
EQUIPO = f"{platform.processor() or platform.machine()} | {os.cpu_count()} núcleos lógicos | Python {platform.python_version()}"
log(f"\nEficiencia computacional ({N_ORIG} orígenes, todos los horizontes) | equipo: {EQUIPO}")
log(EFI.round(4).to_string())

# ----------------------------------------------------------------------------
# 8. ROBUSTEZ: semillas (h = 1)
# ----------------------------------------------------------------------------
idx1 = np.arange(i_test, i_fin + 1)
y1, erw1 = Y[1][idx1], Y[1][idx1] - 0.0
rob = []
for s in SEMILLAS:
    for nombre, maker in [("rf", nuevo_rf), ("xgb", nuevo_xgb)]:
        f = np.array([maker(s).fit(X.iloc[np.arange(i_ini, T)][XRF], Y[1][i_ini:T]).predict(X.iloc[[T]][XRF])[0]
                      for T in idx1])
        e = y1 - f
        lv = tc[idx1] - tc[idx1 - 1] * np.exp(f / 100)
        hit, pt = pesaran_timmermann(y1, f)
        rob.append([nombre, s, sqrt(np.mean(lv ** 2)), 1 - np.sum(e ** 2) / np.sum(erw1 ** 2),
                    dm_hln(e, erw1, 1), clark_west(y1, f, 1), hit, pt])
ROB = pd.DataFrame(rob, columns=["modelo", "semilla", "RMSE_nivel", "R2_oos", "DM_vs_RW_p", "CW_p", "Acierto_dir", "PT_p"])
log("\nRobustez (h = 1):\n" + ROB.round(4).to_string(index=False))

# ----------------------------------------------------------------------------
# 9. INTERPRETACIÓN: SHAP (XGBoost) y dependencia parcial (Random Forest), h = 1
# ----------------------------------------------------------------------------
import shap

tr_idx = np.arange(i_ini, i_test)
Xs = X.iloc[tr_idx][XRF]
xgb_full = nuevo_xgb().fit(Xs, r[tr_idx])
rf_full = nuevo_rf().fit(Xs, r[tr_idx])
sv = shap.TreeExplainer(xgb_full).shap_values(Xs)
SHAPI = pd.Series(np.abs(sv).mean(axis=0), index=XRF).sort_values()

# ----------------------------------------------------------------------------
# 10. FIGURAS
# ----------------------------------------------------------------------------
ETQ = {"rw": "Paseo aleatorio", "drift": "Paseo aleatorio con deriva", "arima": "ARIMA", "garch": "AR-GARCH",
       "var": "VAR", "vecm": "VECM", "ols": "MCO directo", "rf": "Random Forest", "xgb": "XGBoost",
       "combo": "Combinado"}

# 10.1 Importancia por permutación (Objetivo 1)
imp = SEL.rf_import.sort_values()
fig, ax = plt.subplots(figsize=(6.5, 8))
colores = [COL["rf"] if c in XSEL else "#b7d3f6" for c in imp.index]
ax.barh(imp.index, imp.values, color=colores, height=0.6)
ax.axvline(0, color="#8a8a85", lw=0.8)
ax.set_xlabel("Aumento promedio del MSE al permutar (5 bloques)")
ax.set_title("Importancia por permutación (Random Forest)\nazul oscuro = variable seleccionada", loc="left")
ax.grid(axis="y", visible=False)
fig.tight_layout()
fig.savefig(OUT / "fig1_importancia_obj1.png", dpi=200)
plt.close(fig)

# 10.2 Real vs. pronosticado (h = 1)
t_axis = per[idx1].to_timestamp()
fig, ax = plt.subplots(figsize=(9, 4.8))
ax.plot(t_axis, tc[idx1], color=COL["real"], lw=2.2, label="Real")
for m in ["rf", "xgb", "combo"]:
    ax.plot(t_axis, tc[idx1 - 1] * np.exp(F[1][m].values[idx1] / 100), color=COL[m], lw=1.6, label=ETQ[m])
ax.plot(t_axis, tc[idx1 - 1], color=COL["rw"], lw=1.4, ls=":", label=ETQ["rw"])
ax.set_ylabel("Soles por dólar")
ax.set_title("Tipo de cambio: real vs. pronosticado a 1 mes (2021-2025)", loc="left")
ax.legend(ncol=5, frameon=False, loc="upper center", bbox_to_anchor=(0.5, -0.08))
fig.tight_layout()
fig.savefig(OUT / "fig2_real_vs_pronostico.png", dpi=200)
plt.close(fig)

# 10.3 R2 fuera de muestra por horizonte
fig, ax = plt.subplots(figsize=(8, 4.8))
for m in ["rf", "xgb", "arima", "var", "combo"]:
    ax.plot(HORIZ, 100 * R2H.loc[m].values, marker="o", ms=6, color=COL[m], label=ETQ[m])
ax.axhline(0, color="#1f1f1f", lw=1, ls="--")
ax.text(HORIZ[-1], 1, "paseo aleatorio", ha="right", va="bottom", fontsize=9, color="#555")
ax.set_xticks(HORIZ)
ax.set_xlabel("Horizonte (meses)")
ax.set_ylabel("R² fuera de muestra vs. paseo aleatorio (%)")
ax.set_title("Ganancia frente al paseo aleatorio por horizonte", loc="left")
ax.legend(ncol=5, frameon=False, loc="upper center", bbox_to_anchor=(0.5, -0.14))
fig.tight_layout()
fig.savefig(OUT / "fig3_r2_horizontes.png", dpi=200)
plt.close(fig)

# 10.4 Acierto de dirección (h = 1)
ad = MET[1].drop(index="rw").sort_values("Acierto_dir")
fig, ax = plt.subplots(figsize=(7, 4.8))
colores = [COL["rf"] if p < 0.05 else "#b7d3f6" for p in ad.PT_p.fillna(1)]
ax.barh([ETQ[m] for m in ad.index], 100 * ad.Acierto_dir, color=colores, height=0.6)
ax.axvline(50, color="#1f1f1f", lw=1, ls="--")
for yv, (v, p) in enumerate(zip(ad.Acierto_dir, ad.PT_p)):
    ax.text(100 * v + 0.5, yv, f"{100 * v:.1f}%" + (f"  (PT p={p:.3f})" if pd.notna(p) else ""), va="center", fontsize=8.5)
ax.set_xlim(30, 80)
ax.set_xlabel("% de meses en que acierta si el dólar sube o baja")
ax.set_title("Acierto de dirección a 1 mes\nazul oscuro: mejor que el azar (PT p < 0.05)", loc="left")
ax.grid(axis="y", visible=False)
fig.tight_layout()
fig.savefig(OUT / "fig4_acierto_direccion.png", dpi=200)
plt.close(fig)

# 10.5 SHAP (XGBoost)
fig, ax = plt.subplots(figsize=(6.5, 4.5))
ax.barh(SHAPI.index, SHAPI.values, color=COL["xgb"], height=0.6)
ax.set_xlabel("Contribución media |SHAP| al pronóstico del retorno (pp)")
ax.set_title("Qué variables mueven el pronóstico (XGBoost, h = 1)", loc="left")
ax.grid(axis="y", visible=False)
fig.tight_layout()
fig.savefig(OUT / "fig5_shap_xgb.png", dpi=200)
plt.close(fig)

# 10.6 Dependencia parcial (Random Forest): no linealidad
externas = [c for c in SHAPI.sort_values(ascending=False).index if c not in AR][:4]
if externas:
    fig, axs = plt.subplots(1, len(externas), figsize=(3.2 * len(externas), 3.4), sharey=True)
    PartialDependenceDisplay.from_estimator(rf_full, Xs, externas, ax=np.atleast_1d(axs),
                                            line_kw={"color": COL["rf"], "lw": 2})
    for a_ in np.atleast_1d(axs):
        a_.set_ylabel("")
    np.atleast_1d(axs)[0].set_ylabel("Retorno esperado (pp)")
    fig.suptitle("Dependencia parcial (Random Forest, h = 1): efecto de cada variable en el retorno esperado",
                 x=0.01, ha="left", fontsize=10)
    fig.tight_layout()
    fig.savefig(OUT / "fig6_dependencia_parcial.png", dpi=200)
    plt.close(fig)

# 10.7 Eficiencia: tiempo de cómputo frente a precisión (h = 1)
ef = EFI.drop(index=["rw", "drift"]).sort_values("tiempo_medio_por_origen_s")
fig, ax = plt.subplots(figsize=(7, 4.5))
ax.barh([ETQ[m] for m in ef.index], ef.tiempo_medio_por_origen_s,
        color=[COL["rf"] if m == "rf" else "#b7d3f6" for m in ef.index], height=0.6)
for yv, (tt, r2v) in enumerate(zip(ef.tiempo_medio_por_origen_s, ef.R2_oos_h1)):
    ax.text(tt, yv, f"  {tt:.2f} s  (R² h=1: {100 * r2v:+.1f}%)", va="center", fontsize=8.5)
ax.set_xscale("log")
ax.set_xlabel("Segundos por origen de pronóstico (escala logarítmica)")
ax.set_title("Eficiencia computacional por modelo", loc="left")
ax.grid(axis="y", visible=False)
fig.tight_layout()
fig.savefig(OUT / "fig7_eficiencia.png", dpi=200)
plt.close(fig)

# ----------------------------------------------------------------------------
# 11. EXCEL DE RESULTADOS Y ESPECIFICACIONES
# ----------------------------------------------------------------------------
with pd.ExcelWriter(OUT / "resultados_tesis_python.xlsx", engine="openpyxl") as xw:
    UR.round(4).to_excel(xw, sheet_name="Raiz_unitaria")
    s = SEL.copy()
    s.index.name = "candidata"
    s.round(4).to_excel(xw, sheet_name="Obj1_seleccion")
    pd.DataFrame({"nota": [f"Descartadas por disponibilidad: {DESC_DISP}",
                           f"Descartadas por redundancia: {desc_corr}",
                           f"Seleccionadas (>= {VOTOS_MIN} votos): {XSEL}"]}).to_excel(
        xw, sheet_name="Obj1_seleccion", startrow=len(s) + 3, index=False)
    IMPF.round(5).to_excel(xw, sheet_name="Obj1_import_bloques")
    GRID_RF.round(4).to_excel(xw, sheet_name="Obj2_grid_RF", index=False)
    GRID_X.round(4).to_excel(xw, sheet_name="Obj2_grid_XGB", index=False)
    JOH.round(4).to_excel(xw, sheet_name="Johansen", index=False)
    for h in HORIZ:
        MET[h].round(4).to_excel(xw, sheet_name=f"Obj2_h{h}")
    R2H.round(4).to_excel(xw, sheet_name="R2_horizontes")
    ROB.round(4).to_excel(xw, sheet_name="Robustez", index=False)
    EFI.round(5).to_excel(xw, sheet_name="Eficiencia")
    pd.DataFrame({"equipo": [EQUIPO]}).to_excel(xw, sheet_name="Eficiencia", startrow=len(EFI) + 3, index=False)
    SHAPI.sort_values(ascending=False).round(4).to_frame("mean_abs_SHAP").to_excel(xw, sheet_name="SHAP_XGB")
    pron = pd.DataFrame({"fecha": per[idx1].astype(str), "tc": tc[idx1], "r": r[idx1]})
    for h in HORIZ:
        for m in MODELOS:
            pron[f"f{h}_{m}"] = F[h][m].values[idx1]
    pron.round(5).to_excel(xw, sheet_name="Pronosticos", index=False)

pd.concat([df, z.add_prefix("z_"), X.add_prefix("x_")], axis=1).to_csv(OUT / "datos_utilizados.csv")

with open(OUT / "especificaciones_modelos.txt", "w", encoding="utf-8") as fh:
    fh.write("Fuentes actualizadas: " + "; ".join(f"{k}: {v}" for k, v in FUENTE.items()) + "\n")
    fh.write(f"Variables seleccionadas (Objetivo 1): {XSEL}\n")
    fh.write(f"Random Forest: {RF_PAR}, n_estimators={NTREE}\nXGBoost: {XGB_PAR}\n\n")
    fh.write("\n\n".join(str(e) for e in espec))
with open(OUT / "log_python.txt", "w", encoding="utf-8") as fh:
    fh.write("\n".join(LOG))

log(f"\nListo en {time.time() - T_START:.0f} s. Resultados en: {OUT}")
