"""
Unit tests for clinical calculators.
"""
import pytest
from app.clinical_modules.calculators import (
    calculate_curb65,
    calculate_wells_pe,
    calculate_glasgow_coma_scale,
    calculate_chads2_vasc,
    get_available_calculators,
    CalculatorResult
)


@pytest.mark.unit
@pytest.mark.services
class TestCURB65Calculator:
    """Test CURB-65 pneumonia severity calculator."""

    def test_curb65_low_risk(self):
        """Test CURB-65 calculation for low risk patient."""
        result = calculate_curb65(
            confusion=False,
            urea=5.0,
            respiratory_rate=18,
            blood_pressure_systolic=130,
            blood_pressure_diastolic=80,
            age=45
        )
        
        assert isinstance(result, CalculatorResult)
        assert result.score == 0
        assert result.risk_level == "Bajo"
        assert "ambulatorio" in result.interpretation.lower()
        assert "ambulatorio" in result.recommendations.lower()

    def test_curb65_moderate_risk(self):
        """Test CURB-65 calculation for moderate risk patient."""
        result = calculate_curb65(
            confusion=True,
            urea=8.5,
            respiratory_rate=35,
            blood_pressure_systolic=110,
            blood_pressure_diastolic=70,
            age=72
        )
        
        assert result.score == 3  # C + R + Age (urea 8.5 is below threshold 19)
        assert result.risk_level == "Alto"
        assert "hospitalización" in result.recommendations.lower()

    def test_curb65_high_risk(self):
        """Test CURB-65 calculation for high risk patient."""
        result = calculate_curb65(
            confusion=True,
            urea=15.0,
            respiratory_rate=35,
            blood_pressure_systolic=85,
            blood_pressure_diastolic=50,
            age=75
        )
        
        assert result.score == 4  # C + R + B + Age (urea 15 is below threshold 19)
        assert result.risk_level == "Severo"
        assert "UCI" in result.recommendations

    def test_curb65_edge_cases(self):
        """Test CURB-65 with edge case values."""
        # Exactly on thresholds
        result = calculate_curb65(
            confusion=False,
            urea=20.0,  # Above threshold of 19
            respiratory_rate=30,  # Exactly at threshold
            blood_pressure_systolic=90,  # Exactly at threshold
            blood_pressure_diastolic=60,  # Exactly at threshold
            age=65  # Exactly at threshold
        )
        
        assert result.score == 4  # U + R + B + Age

    def test_curb65_invalid_inputs(self):
        """Test CURB-65 with invalid inputs."""
        with pytest.raises(ValueError):
            calculate_curb65(
                confusion=False,
                urea=-1.0,  # Invalid negative value
                respiratory_rate=20,
                blood_pressure_systolic=120,
                blood_pressure_diastolic=80,
                age=50
            )

        with pytest.raises(ValueError):
            calculate_curb65(
                confusion=False,
                urea=5.0,
                respiratory_rate=0,  # Invalid zero value
                blood_pressure_systolic=120,
                blood_pressure_diastolic=80,
                age=50
            )


@pytest.mark.unit
@pytest.mark.services
class TestWellsPECalculator:
    """Test Wells PE score calculator."""

    def test_wells_pe_low_probability(self):
        """Test Wells PE for low probability."""
        result = calculate_wells_pe(
            clinical_signs_dvt=False,
            pe_likely=False,
            heart_rate_over_100=False,
            immobilization_surgery=False,
            previous_pe_dvt=False,
            hemoptysis=False,
            malignancy=False
        )
        
        assert result.score == 0
        assert result.risk_level == "Bajo"
        assert "baja probabilidad" in result.interpretation.lower()

    def test_wells_pe_moderate_probability(self):
        """Test Wells PE for moderate probability."""
        result = calculate_wells_pe(
            clinical_signs_dvt=True,  # +3
            pe_likely=False,
            heart_rate_over_100=True,  # +1.5
            immobilization_surgery=True,  # +1.5
            previous_pe_dvt=False,
            hemoptysis=False,
            malignancy=False
        )
        
        assert result.score == 6.0
        assert result.risk_level == "Alto"

    def test_wells_pe_high_probability(self):
        """Test Wells PE for high probability."""
        result = calculate_wells_pe(
            clinical_signs_dvt=True,  # +3
            pe_likely=True,  # +3
            heart_rate_over_100=True,  # +1.5
            immobilization_surgery=True,  # +1.5
            previous_pe_dvt=True,  # +1.5
            hemoptysis=True,  # +1
            malignancy=True  # +1
        )
        
        assert result.score == 12.5
        assert result.risk_level == "Alto"
        assert "TC pulmonar" in result.recommendations


@pytest.mark.unit
@pytest.mark.services
class TestGlasgowComaCalculator:
    """Test Glasgow Coma Scale calculator."""

    def test_glasgow_normal(self):
        """Test Glasgow Coma Scale for normal patient."""
        result = calculate_glasgow_coma_scale(
            eye_opening=4,
            verbal_response=5,
            motor_response=6
        )
        
        assert result.score == 15
        assert result.risk_level == "Normal"
        assert "normal" in result.interpretation.lower()

    def test_glasgow_moderate_injury(self):
        """Test Glasgow Coma Scale for moderate injury."""
        result = calculate_glasgow_coma_scale(
            eye_opening=3,
            verbal_response=4,
            motor_response=5
        )
        
        assert result.score == 12
        assert result.risk_level == "Moderado"

    def test_glasgow_severe_injury(self):
        """Test Glasgow Coma Scale for severe injury."""
        result = calculate_glasgow_coma_scale(
            eye_opening=2,
            verbal_response=2,
            motor_response=3
        )
        
        assert result.score == 7
        assert result.risk_level == "Severo"
        assert "grave" in result.interpretation.lower()

    def test_glasgow_invalid_scores(self):
        """Test Glasgow Coma Scale with invalid scores."""
        with pytest.raises(ValueError):
            calculate_glasgow_coma_scale(
                eye_opening=5,  # Invalid, max is 4
                verbal_response=5,
                motor_response=6
            )

        with pytest.raises(ValueError):
            calculate_glasgow_coma_scale(
                eye_opening=4,
                verbal_response=6,  # Invalid, max is 5
                motor_response=6
            )

        with pytest.raises(ValueError):
            calculate_glasgow_coma_scale(
                eye_opening=4,
                verbal_response=5,
                motor_response=7  # Invalid, max is 6
            )


@pytest.mark.unit
@pytest.mark.services
class TestCHADS2VAScCalculator:
    """Test CHA2DS2-VASc stroke risk calculator."""

    def test_chads2vasc_low_risk(self):
        """Test CHA2DS2-VASc for low risk patient."""
        result = calculate_chads2_vasc(
            congestive_heart_failure=False,
            hypertension=False,
            age=45,
            diabetes=False,
            stroke_tia_history=False,
            vascular_disease=False,
            sex_female=False
        )
        
        assert result.score == 0
        assert result.risk_level == "Bajo"
        assert "bajo riesgo" in result.interpretation.lower()

    def test_chads2vasc_moderate_risk(self):
        """Test CHA2DS2-VASc for moderate risk patient."""
        result = calculate_chads2_vasc(
            congestive_heart_failure=True,  # +1
            hypertension=True,  # +1
            age=68,  # +1 (65-74)
            diabetes=False,
            stroke_tia_history=False,
            vascular_disease=False,
            sex_female=True  # +1
        )
        
        assert result.score == 4
        assert result.risk_level == "Alto"

    def test_chads2vasc_high_risk(self):
        """Test CHA2DS2-VASc for high risk patient."""
        result = calculate_chads2_vasc(
            congestive_heart_failure=True,  # +1
            hypertension=True,  # +1
            age=78,  # +2 (≥75)
            diabetes=True,  # +1
            stroke_tia_history=True,  # +2
            vascular_disease=True,  # +1
            sex_female=True  # +1
        )
        
        assert result.score == 9
        assert result.risk_level == "Alto"
        assert "anticoagulación" in result.recommendations.lower()

    def test_chads2vasc_age_scoring(self):
        """Test age-specific scoring in CHA2DS2-VASc."""
        # Age < 65: 0 points
        result_young = calculate_chads2_vasc(
            congestive_heart_failure=False,
            hypertension=False,
            age=50,
            diabetes=False,
            stroke_tia_history=False,
            vascular_disease=False,
            sex_female=False
        )
        assert result_young.score == 0

        # Age 65-74: 1 point
        result_middle = calculate_chads2_vasc(
            congestive_heart_failure=False,
            hypertension=False,
            age=70,
            diabetes=False,
            stroke_tia_history=False,
            vascular_disease=False,
            sex_female=False
        )
        assert result_middle.score == 1

        # Age ≥75: 2 points
        result_old = calculate_chads2_vasc(
            congestive_heart_failure=False,
            hypertension=False,
            age=80,
            diabetes=False,
            stroke_tia_history=False,
            vascular_disease=False,
            sex_female=False
        )
        assert result_old.score == 2


@pytest.mark.unit
@pytest.mark.services
class TestCalculatorResult:
    """Test CalculatorResult class."""

    def test_calculator_result_creation(self):
        """Test CalculatorResult creation."""
        result = CalculatorResult(
            calculator_name="Test Calculator",
            score=5,
            risk_level="Moderate",
            interpretation="Test interpretation",
            recommendations="Test recommendations"
        )
        
        assert result.calculator_name == "Test Calculator"
        assert result.score == 5
        assert result.risk_level == "Moderate"
        assert result.interpretation == "Test interpretation"
        assert result.recommendations == "Test recommendations"

    def test_calculator_result_to_dict(self):
        """Test CalculatorResult to_dict method."""
        result = CalculatorResult(
            calculator_name="Test Calculator",
            score=3,
            risk_level="Low",
            interpretation="Test interpretation",
            recommendations="Test recommendations"
        )
        
        result_dict = result.to_dict()
        
        expected_keys = {
            'calculator_name', 'score', 'risk_level', 
            'interpretation', 'recommendations'
        }
        
        assert set(result_dict.keys()) == expected_keys
        assert result_dict['calculator_name'] == "Test Calculator"
        assert result_dict['score'] == 3


@pytest.mark.unit
@pytest.mark.services
class TestCalculatorUtilities:
    """Test calculator utility functions."""

    def test_get_available_calculators(self):
        """Test getting list of available calculators."""
        calculators = get_available_calculators()
        
        assert isinstance(calculators, dict)
        assert 'calculators' in calculators
        
        calculator_list = calculators['calculators']
        calculator_names = [calc['name'] for calc in calculator_list]
        
        expected_calculators = ['CURB-65', 'Wells PE', 'Glasgow Coma Scale', 'CHA2DS2-VASc']
        
        for expected in expected_calculators:
            assert expected in calculator_names

        # Check that each calculator has required fields
        for calculator in calculator_list:
            assert 'name' in calculator
            assert 'description' in calculator
            assert 'category' in calculator
            assert 'input_fields' in calculator


@pytest.mark.unit
@pytest.mark.services
class TestCalculatorIntegration:
    """Test calculator integration scenarios."""

    def test_multiple_calculator_consistency(self, sample_medical_data):
        """Test that calculators produce consistent results."""
        # Test CURB-65
        curb65_data = sample_medical_data['curb65']
        curb65_result = calculate_curb65(**curb65_data)
        
        # Test Wells PE
        wells_data = sample_medical_data['wells_pe']
        wells_result = calculate_wells_pe(**wells_data)
        
        # Test Glasgow
        glasgow_data = sample_medical_data['glasgow_coma']
        glasgow_result = calculate_glasgow_coma_scale(**glasgow_data)
        
        # Test CHA2DS2-VASc
        chads_data = sample_medical_data['chads2_vasc']
        chads_result = calculate_chads2_vasc(**chads_data)
        
        # All should return CalculatorResult objects
        results = [curb65_result, wells_result, glasgow_result, chads_result]
        
        for result in results:
            assert isinstance(result, CalculatorResult)
            assert hasattr(result, 'score')
            assert hasattr(result, 'risk_level')
            assert hasattr(result, 'interpretation')
            assert hasattr(result, 'recommendations')
            assert result.score >= 0
            assert result.risk_level in ['Bajo', 'Moderado', 'Alto', 'Severo', 'Normal']

    def test_calculator_error_handling(self):
        """Test that calculators handle errors appropriately."""
        # Test with None values
        with pytest.raises(TypeError):
            calculate_curb65(None, 5.0, 20, 120, 80, 50)

        # Test with string values where numbers expected
        with pytest.raises(TypeError):
            calculate_wells_pe(
                clinical_signs_dvt="yes",  # Should be boolean
                pe_likely=False,
                heart_rate_over_100=False,
                immobilization_surgery=False,
                previous_pe_dvt=False,
                hemoptysis=False,
                malignancy=False
            )

    def test_calculator_edge_cases_comprehensive(self):
        """Test comprehensive edge cases for all calculators."""
        # CURB-65 with all positive criteria
        curb65_max = calculate_curb65(True, 50.0, 50, 50, 30, 90)
        assert curb65_max.score == 5
        assert curb65_max.risk_level == "Severo"

        # Wells PE with all negative criteria
        wells_min = calculate_wells_pe(False, False, False, False, False, False, False)
        assert wells_min.score == 0
        assert wells_min.risk_level == "Bajo"

        # Glasgow with minimum scores
        glasgow_min = calculate_glasgow_coma_scale(1, 1, 1)
        assert glasgow_min.score == 3
        assert glasgow_min.risk_level == "Severo"

        # CHA2DS2-VASc with maximum realistic score
        chads_max = calculate_chads2_vasc(True, True, 85, True, True, True, True)
        assert chads_max.score == 9
        assert chads_max.risk_level == "Alto"