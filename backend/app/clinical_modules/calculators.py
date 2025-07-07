"""
Módulo de calculadoras médicas
Contiene funciones puras para calcular scores clínicos comunes
"""

from typing import Dict, Any, Optional
from enum import Enum


class RiskLevel(Enum):
    """Niveles de riesgo"""
    LOW = "Bajo"
    MODERATE = "Moderado"
    HIGH = "Alto"
    SEVERE = "Severo"


class CalculatorResult:
    """Clase para representar el resultado de una calculadora"""
    def __init__(self, score: float, risk_level: RiskLevel, interpretation: str, recommendations: str = ""):
        self.score = score
        self.risk_level = risk_level
        self.interpretation = interpretation
        self.recommendations = recommendations
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            "score": self.score,
            "risk_level": self.risk_level.value,
            "interpretation": self.interpretation,
            "recommendations": self.recommendations
        }


def _validate_numeric_range(value: float, min_val: float, max_val: float, name: str):
    """Validar que un valor numérico esté en el rango esperado"""
    if value < min_val or value > max_val:
        raise ValueError(f"{name} debe estar entre {min_val} y {max_val}")

def calculate_curb65(
    confusion: bool,
    urea: float,
    respiratory_rate: int,
    blood_pressure_systolic: int,
    blood_pressure_diastolic: int,
    age: int
) -> CalculatorResult:
    """
    Calcula el score CURB-65 para neumonía adquirida en la comunidad
    
    Args:
        confusion: Confusión mental presente
        urea: Nivel de urea en mg/dL
        respiratory_rate: Frecuencia respiratoria por minuto
        blood_pressure_systolic: Presión arterial sistólica
        blood_pressure_diastolic: Presión arterial diastólica
        age: Edad del paciente
    
    Returns:
        CalculatorResult con el score y interpretación
    """
    # Validar inputs
    _validate_numeric_range(urea, 0, 500, "Urea")
    _validate_numeric_range(respiratory_rate, 0, 100, "Frecuencia respiratoria")
    _validate_numeric_range(blood_pressure_systolic, 40, 300, "Presión arterial sistólica")
    _validate_numeric_range(blood_pressure_diastolic, 20, 200, "Presión arterial diastólica")
    _validate_numeric_range(age, 0, 150, "Edad")
    
    score = 0
    
    # C - Confusión
    if confusion:
        score += 1
    
    # U - Urea > 19 mg/dL (7 mmol/L)
    if urea > 19:
        score += 1
    
    # R - Frecuencia respiratoria ≥ 30/min
    if respiratory_rate >= 30:
        score += 1
    
    # B - Presión arterial baja (sistólica < 90 o diastólica ≤ 60)
    if blood_pressure_systolic < 90 or blood_pressure_diastolic <= 60:
        score += 1
    
    # 65 - Edad ≥ 65 años
    if age >= 65:
        score += 1
    
    # Interpretación del score
    if score == 0:
        risk_level = RiskLevel.LOW
        interpretation = "Riesgo bajo de mortalidad (0.7%)"
        recommendations = "Manejo ambulatorio. Considerar tratamiento oral."
    elif score == 1:
        risk_level = RiskLevel.LOW
        interpretation = "Riesgo bajo de mortalidad (2.1%)"
        recommendations = "Manejo ambulatorio. Considerar tratamiento oral."
    elif score == 2:
        risk_level = RiskLevel.MODERATE
        interpretation = "Riesgo moderado de mortalidad (9.2%)"
        recommendations = "Considerar hospitalización. Tratamiento antibiótico endovenoso."
    elif score == 3:
        risk_level = RiskLevel.HIGH
        interpretation = "Riesgo alto de mortalidad (14.5%)"
        recommendations = "Hospitalización recomendada. Considerar UCI si hay deterioro."
    else:  # score >= 4
        risk_level = RiskLevel.SEVERE
        interpretation = "Riesgo muy alto de mortalidad (40%)"
        recommendations = "Hospitalización urgente. Considerar manejo en UCI."
    
    return CalculatorResult(score, risk_level, interpretation, recommendations)


def calculate_wells_pe(
    clinical_signs_dvt: bool,
    pe_likely: bool,
    heart_rate_over_100: bool,
    immobilization_surgery: bool,
    previous_pe_dvt: bool,
    hemoptysis: bool,
    malignancy: bool
) -> CalculatorResult:
    """
    Calcula el score de Wells para embolia pulmonar
    
    Args:
        clinical_signs_dvt: Signos clínicos de TVP (3 puntos)
        pe_likely: EP es el diagnóstico más probable (3 puntos)
        heart_rate_over_100: FC > 100 lpm (1.5 puntos)
        immobilization_surgery: Inmovilización/cirugía en últimas 4 semanas (1.5 puntos)
        previous_pe_dvt: EP o TVP previa (1.5 puntos)
        hemoptysis: Hemoptisis (1 punto)
        malignancy: Malignidad activa (1 punto)
    
    Returns:
        CalculatorResult con el score y interpretación
    """
    score = 0.0
    
    if clinical_signs_dvt:
        score += 3.0
    if pe_likely:
        score += 3.0
    if heart_rate_over_100:
        score += 1.5
    if immobilization_surgery:
        score += 1.5
    if previous_pe_dvt:
        score += 1.5
    if hemoptysis:
        score += 1.0
    if malignancy:
        score += 1.0
    
    # Interpretación del score
    if score <= 4.0:
        risk_level = RiskLevel.LOW
        interpretation = f"Probabilidad baja de EP ({score} puntos). Probabilidad < 12%"
        recommendations = "Considerar dímero D. Si negativo, EP poco probable."
    elif score <= 6.0:
        risk_level = RiskLevel.MODERATE
        interpretation = f"Probabilidad moderada de EP ({score} puntos). Probabilidad 12-37%"
        recommendations = "Realizar estudios de imagen (AngioTC o gammagrafía)."
    else:
        risk_level = RiskLevel.HIGH
        interpretation = f"Probabilidad alta de EP ({score} puntos). Probabilidad > 37%"
        recommendations = "AngioTC urgente. Considerar anticoagulación empírica si hay retraso."
    
    return CalculatorResult(score, risk_level, interpretation, recommendations)


def calculate_glasgow_coma_scale(
    eye_opening: int,
    verbal_response: int,
    motor_response: int
) -> CalculatorResult:
    """
    Calcula la Escala de Coma de Glasgow
    
    Args:
        eye_opening: Apertura ocular (1-4)
        verbal_response: Respuesta verbal (1-5)
        motor_response: Respuesta motora (1-6)
    
    Returns:
        CalculatorResult con el score y interpretación
    """
    # Validación de rangos
    if not (1 <= eye_opening <= 4):
        raise ValueError("Apertura ocular debe estar entre 1-4")
    if not (1 <= verbal_response <= 5):
        raise ValueError("Respuesta verbal debe estar entre 1-5")
    if not (1 <= motor_response <= 6):
        raise ValueError("Respuesta motora debe estar entre 1-6")
    
    score = eye_opening + verbal_response + motor_response
    
    # Interpretación del score
    if score >= 13:
        risk_level = RiskLevel.LOW
        interpretation = f"Lesión cerebral leve (GCS {score})"
        recommendations = "Observación. Monitoreo neurológico rutinario."
    elif score >= 9:
        risk_level = RiskLevel.MODERATE
        interpretation = f"Lesión cerebral moderada (GCS {score})"
        recommendations = "Hospitalización. Monitoreo neurológico frecuente. Considerar TC."
    else:
        risk_level = RiskLevel.SEVERE
        interpretation = f"Lesión cerebral severa (GCS {score})"
        recommendations = "UCI. Manejo de vía aérea. TC urgente. Monitoreo PIC."
    
    return CalculatorResult(score, risk_level, interpretation, recommendations)


def calculate_nihss(
    consciousness: int,
    orientation: int,
    commands: int,
    gaze: int,
    visual_fields: int,
    facial_palsy: int,
    motor_arm_left: int,
    motor_arm_right: int,
    motor_leg_left: int,
    motor_leg_right: int,
    ataxia: int,
    sensory: int,
    language: int,
    dysarthria: int,
    extinction: int
) -> CalculatorResult:
    """
    Calcula el National Institutes of Health Stroke Scale (NIHSS)
    
    Args:
        consciousness: Nivel de conciencia (0-3)
        orientation: Orientación (0-2)
        commands: Seguimiento de órdenes (0-2)
        gaze: Movimientos oculares (0-2)
        visual_fields: Campos visuales (0-3)
        facial_palsy: Parálisis facial (0-3)
        motor_arm_left: Motor brazo izquierdo (0-4)
        motor_arm_right: Motor brazo derecho (0-4)
        motor_leg_left: Motor pierna izquierda (0-4)
        motor_leg_right: Motor pierna derecha (0-4)
        ataxia: Ataxia (0-2)
        sensory: Sensitivo (0-2)
        language: Lenguaje (0-3)
        dysarthria: Disartria (0-2)
        extinction: Extinción/inatención (0-2)
    
    Returns:
        CalculatorResult con el score y interpretación
    """
    score = (consciousness + orientation + commands + gaze + visual_fields + 
             facial_palsy + motor_arm_left + motor_arm_right + motor_leg_left + 
             motor_leg_right + ataxia + sensory + language + dysarthria + extinction)
    
    # Interpretación del score
    if score == 0:
        risk_level = RiskLevel.LOW
        interpretation = f"Sin síntomas de stroke (NIHSS {score})"
        recommendations = "Paciente sin déficit neurológico detectable."
    elif score <= 4:
        risk_level = RiskLevel.LOW
        interpretation = f"Stroke menor (NIHSS {score})"
        recommendations = "Stroke leve. Considerar trombolisis según criterios."
    elif score <= 15:
        risk_level = RiskLevel.MODERATE
        interpretation = f"Stroke moderado (NIHSS {score})"
        recommendations = "Stroke moderado. Candidato para trombolisis/trombectomía."
    elif score <= 20:
        risk_level = RiskLevel.HIGH
        interpretation = f"Stroke moderado-severo (NIHSS {score})"
        recommendations = "Stroke severo. Trombolisis/trombectomía urgente si es candidato."
    else:
        risk_level = RiskLevel.SEVERE
        interpretation = f"Stroke severo (NIHSS {score})"
        recommendations = "Stroke muy severo. Evaluar tratamiento agresivo vs. cuidados paliativos."
    
    return CalculatorResult(score, risk_level, interpretation, recommendations)


def calculate_chads2_vasc(
    congestive_heart_failure: bool,
    hypertension: bool,
    age: int,
    diabetes: bool,
    stroke_tia_history: bool,
    vascular_disease: bool,
    sex_female: bool
) -> CalculatorResult:
    """
    Calcula el score CHA2DS2-VASc para riesgo de stroke en fibrilación auricular
    
    Args:
        congestive_heart_failure: Insuficiencia cardíaca congestiva (1 punto)
        hypertension: Hipertensión (1 punto)
        age: Edad del paciente (0, 1 o 2 puntos según edad)
        diabetes: Diabetes (1 punto)
        stroke_tia_history: Historia de stroke/TIA (2 puntos)
        vascular_disease: Enfermedad vascular (1 punto)
        sex_female: Sexo femenino (1 punto)
    
    Returns:
        CalculatorResult con el score y interpretación
    """
    # Validar inputs
    _validate_numeric_range(age, 0, 150, "Edad")
    
    score = 0
    
    if congestive_heart_failure:
        score += 1
    if hypertension:
        score += 1
    if age >= 75:
        score += 2
    elif age >= 65:
        score += 1
    if diabetes:
        score += 1
    if stroke_tia_history:
        score += 2
    if vascular_disease:
        score += 1
    if sex_female:
        score += 1
    
    # Interpretación del score
    if score == 0:
        risk_level = RiskLevel.LOW
        interpretation = f"Riesgo muy bajo de stroke (CHA2DS2-VASc {score}). Riesgo anual: 0%"
        recommendations = "No anticoagulación. Considerar aspirina."
    elif score == 1:
        risk_level = RiskLevel.LOW
        interpretation = f"Riesgo bajo de stroke (CHA2DS2-VASc {score}). Riesgo anual: 1.3%"
        recommendations = "Considerar anticoagulación oral o aspirina."
    elif score == 2:
        risk_level = RiskLevel.MODERATE
        interpretation = f"Riesgo moderado de stroke (CHA2DS2-VASc {score}). Riesgo anual: 2.2%"
        recommendations = "Anticoagulación oral recomendada."
    else:
        risk_level = RiskLevel.HIGH
        interpretation = f"Riesgo alto de stroke (CHA2DS2-VASc {score}). Riesgo anual: {3.2 + (score-3)*0.8:.1f}%"
        recommendations = "Anticoagulación oral fuertemente recomendada."
    
    return CalculatorResult(score, risk_level, interpretation, recommendations)


def calculate_apache_ii(
    temperature: float,
    mean_arterial_pressure: float,
    heart_rate: int,
    respiratory_rate: int,
    oxygenation: float,
    arterial_ph: float,
    sodium: float,
    potassium: float,
    creatinine: float,
    hematocrit: float,
    white_blood_cells: float,
    glasgow_coma_scale: int,
    age: int,
    chronic_health: bool
) -> CalculatorResult:
    """
    Calcula el score APACHE II (simplificado)
    
    Returns:
        CalculatorResult con el score y interpretación
    """
    score = 0
    
    # Temperatura (°C)
    if temperature >= 41 or temperature <= 29.9:
        score += 4
    elif (temperature >= 39) or (temperature <= 31.9):
        score += 3
    elif (temperature >= 38.5) or (temperature <= 33.9):
        score += 1
    
    # Presión arterial media
    if mean_arterial_pressure >= 160 or mean_arterial_pressure <= 49:
        score += 4
    elif (mean_arterial_pressure >= 130) or (mean_arterial_pressure <= 69):
        score += 2
    elif mean_arterial_pressure <= 109:
        score += 2
    
    # Frecuencia cardíaca
    if heart_rate >= 180 or heart_rate <= 39:
        score += 4
    elif (heart_rate >= 140) or (heart_rate <= 54):
        score += 2
    elif (heart_rate >= 110) or (heart_rate <= 69):
        score += 1
    
    # Glasgow Coma Scale
    gcs_points = 15 - glasgow_coma_scale
    score += gcs_points
    
    # Edad
    if age >= 75:
        score += 6
    elif age >= 65:
        score += 5
    elif age >= 55:
        score += 3
    elif age >= 45:
        score += 2
    
    # Enfermedad crónica
    if chronic_health:
        score += 5
    
    # Interpretación del score
    if score <= 4:
        risk_level = RiskLevel.LOW
        interpretation = f"Riesgo bajo de mortalidad (APACHE II {score}). Mortalidad estimada: <4%"
        recommendations = "Paciente estable. Monitoreo rutinario."
    elif score <= 14:
        risk_level = RiskLevel.MODERATE
        interpretation = f"Riesgo moderado de mortalidad (APACHE II {score}). Mortalidad estimada: 8-15%"
        recommendations = "Monitoreo cercano. Considerar cuidados intermedios."
    elif score <= 24:
        risk_level = RiskLevel.HIGH
        interpretation = f"Riesgo alto de mortalidad (APACHE II {score}). Mortalidad estimada: 15-25%"
        recommendations = "UCI recomendada. Soporte intensivo."
    else:
        risk_level = RiskLevel.SEVERE
        interpretation = f"Riesgo muy alto de mortalidad (APACHE II {score}). Mortalidad estimada: >40%"
        recommendations = "UCI. Soporte vital máximo. Considerar pronóstico."
    
    return CalculatorResult(score, risk_level, interpretation, recommendations)


def get_available_calculators() -> Dict[str, Dict[str, Any]]:
    """
    Retorna la lista de calculadoras disponibles con su información
    
    Returns:
        Diccionario con información de las calculadoras
    """
    return {
        "curb65": {
            "name": "CURB-65",
            "description": "Score para evaluar severidad de neumonía adquirida en la comunidad",
            "category": "Respiratorio",
            "parameters": [
                {"name": "confusion", "type": "boolean", "label": "Confusión mental"},
                {"name": "urea", "type": "number", "label": "Urea (mg/dL)", "unit": "mg/dL"},
                {"name": "respiratory_rate", "type": "integer", "label": "Frecuencia respiratoria", "unit": "/min"},
                {"name": "blood_pressure_systolic", "type": "integer", "label": "Presión arterial sistólica", "unit": "mmHg"},
                {"name": "blood_pressure_diastolic", "type": "integer", "label": "Presión arterial diastólica", "unit": "mmHg"},
                {"name": "age", "type": "integer", "label": "Edad", "unit": "años"}
            ]
        },
        "wells_pe": {
            "name": "Wells PE",
            "description": "Score para probabilidad de embolia pulmonar",
            "category": "Cardiovascular",
            "parameters": [
                {"name": "clinical_signs_dvt", "type": "boolean", "label": "Signos clínicos de TVP"},
                {"name": "pe_likely", "type": "boolean", "label": "EP es el diagnóstico más probable"},
                {"name": "heart_rate_over_100", "type": "boolean", "label": "FC > 100 lpm"},
                {"name": "immobilization_surgery", "type": "boolean", "label": "Inmovilización/cirugía (4 semanas)"},
                {"name": "previous_pe_dvt", "type": "boolean", "label": "EP o TVP previa"},
                {"name": "hemoptysis", "type": "boolean", "label": "Hemoptisis"},
                {"name": "malignancy", "type": "boolean", "label": "Malignidad activa"}
            ]
        },
        "glasgow_coma": {
            "name": "Escala de Coma de Glasgow",
            "description": "Evaluación del nivel de conciencia",
            "category": "Neurológico",
            "parameters": [
                {"name": "eye_opening", "type": "select", "label": "Apertura ocular", "options": [
                    {"value": 4, "label": "Espontánea"},
                    {"value": 3, "label": "Al habla"},
                    {"value": 2, "label": "Al dolor"},
                    {"value": 1, "label": "Ninguna"}
                ]},
                {"name": "verbal_response", "type": "select", "label": "Respuesta verbal", "options": [
                    {"value": 5, "label": "Orientada"},
                    {"value": 4, "label": "Confusa"},
                    {"value": 3, "label": "Palabras inapropiadas"},
                    {"value": 2, "label": "Sonidos incomprensibles"},
                    {"value": 1, "label": "Ninguna"}
                ]},
                {"name": "motor_response", "type": "select", "label": "Respuesta motora", "options": [
                    {"value": 6, "label": "Obedece órdenes"},
                    {"value": 5, "label": "Localiza dolor"},
                    {"value": 4, "label": "Retira al dolor"},
                    {"value": 3, "label": "Flexión anormal"},
                    {"value": 2, "label": "Extensión anormal"},
                    {"value": 1, "label": "Ninguna"}
                ]}
            ]
        },
        "chads2_vasc": {
            "name": "CHA2DS2-VASc",
            "description": "Riesgo de stroke en fibrilación auricular",
            "category": "Cardiovascular",
            "parameters": [
                {"name": "congestive_heart_failure", "type": "boolean", "label": "Insuficiencia cardíaca congestiva"},
                {"name": "hypertension", "type": "boolean", "label": "Hipertensión"},
                {"name": "age", "type": "integer", "label": "Edad", "unit": "años"},
                {"name": "diabetes", "type": "boolean", "label": "Diabetes"},
                {"name": "stroke_tia_history", "type": "boolean", "label": "Historia de stroke/TIA"},
                {"name": "vascular_disease", "type": "boolean", "label": "Enfermedad vascular"},
                {"name": "sex_female", "type": "boolean", "label": "Sexo femenino"}
            ]
        }
    }