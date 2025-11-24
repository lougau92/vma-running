# file: training_plan_converter_ui.py
import streamlit as st
import json
import re
from typing import List, Dict, Any

class TrainingPlanConverter:
    def __init__(self):
        self.recovery_type_map = {
            'actif': 'active',
            'actif (pour les plus en forme)': 'active',
            'marche': 'walk',
            'trott': 'jog',
            'pause sèche': 'rest'
        }
    
    def parse_recovery_type(self, text: str) -> str:
        text_lower = text.lower()
        for key, value in self.recovery_type_map.items():
            if key in text_lower:
                return value
        return 'rest'
    
    def parse_time_to_seconds(self, time_str: str) -> float:
        time_str = time_str.replace('min', '').replace("'", '').replace('"', '').strip()
        
        if '’' in time_str:
            parts = time_str.split('’')
            if len(parts) == 2:
                minutes = float(parts[0]) if parts[0] else 0
                seconds = float(parts[1]) if parts[1] else 0
                return minutes * 60 + seconds
            else:
                return float(parts[0]) * 60
        else:
            return float(time_str) * 60
    
    def parse_training_notes(self, text: str) -> Dict[str, Any]:
        warmup_match = re.search(r'Échauffement\s*(.+)', text)
        warmup = warmup_match.group(1).strip() if warmup_match else "Échauffement 15' boucle habituelle + 3 gammes"
        
        cooldown_match = re.search(r'Retour au calme\s*(.+)', text)
        cooldown = cooldown_match.group(1).strip() if cooldown_match else "Retour au calme en footing lent autour de la piste dans le sens horlogique 5'"
        
        remarks_match = re.search(r'Remarques supplémentaires\s*:\s*(.+)', text, re.DOTALL)
        remarks = remarks_match.group(1).strip() if remarks_match else "Bien respecter les % de VMA très important."
        
        groups = []
        
        # Split by group sections
        group_sections = re.split(r'Bloc GROUPE\s*(\d+)\s*:', text)
        
        for i in range(1, len(group_sections), 2):
            if i + 1 < len(group_sections):
                group_number = group_sections[i]
                group_content = group_sections[i + 1]
                
                blocks = []
                
                # Better block splitting
                block_parts = re.split(r'(Bloc\s+\d+)', group_content)
                
                for j in range(1, len(block_parts), 2):
                    if j + 1 < len(block_parts):
                        block_title_match = re.search(r'Bloc\s+(\d+)', block_parts[j])
                        if block_title_match:
                            block_title = f"Bloc {block_title_match.group(1)}"
                            block_content = block_parts[j + 1]
                            
                            # FIX: More flexible interval line pattern
                            # Handles both "3x 1200" and "3 x 800" patterns
                            interval_lines = re.findall(r'-\s*(\d+\s*x\s*\d+\s*[\d%-]+)', block_content)
                            
                            # Debug output
                            print(f"Block content: {block_title}")
                            print(f"Interval lines: {interval_lines}")
                            
                            sets = []
                            
                            for line in interval_lines:
                                sets.extend(self.parse_interval_set(line))
                            
                            # Parse recovery times for each set
                            recovery_pattern = r"(\d+[''']?\d*)\s*(actif|pause sèche|marche|trott)"
                            recovery_matches = list(re.finditer(recovery_pattern, block_content))
                            
                            for k, set_data in enumerate(sets):
                                if k < len(recovery_matches):
                                    match = recovery_matches[k]
                                    time_str, recovery_type_str = match.groups()
                                    set_data['recoverySeconds'] = self.parse_time_to_seconds(time_str)
                                    set_data['recoveryType'] = self.parse_recovery_type(recovery_type_str)
                            
                            # Parse after-recovery for the entire block
                            after_recovery_seconds = None
                            after_recovery_type = 'rest'
                            
                            after_recovery_match = re.search(r"(\d+[''']?\d*)\s*(pause sèche)", block_content)
                            if after_recovery_match:
                                after_recovery_seconds = self.parse_time_to_seconds(after_recovery_match.group(1))
                                after_recovery_type = self.parse_recovery_type(after_recovery_match.group(2))
                            
                            block_data = {
                                'title': block_title,
                                'sets': sets
                            }
                            
                            if after_recovery_seconds:
                                block_data['afterRecoverySeconds'] = after_recovery_seconds
                                block_data['afterRecoveryType'] = after_recovery_type
                            else:
                                # Default after recovery
                                block_data['afterRecoverySeconds'] = 180
                                block_data['afterRecoveryType'] = 'rest'
                            
                            blocks.append(block_data)
                
                groups.append({
                    'title': f'Groupe {group_number}',
                    'blocks': blocks
                })
        
        return {
            'title': 'Mercredi (séance piste)',
            'warmup': warmup,
            'cooldown': cooldown,
            'remarks': remarks,
            'groups': groups
        }

    def parse_interval_set(self, text: str) -> List[Dict[str, Any]]:
        sets = []
        
        # FIX: More flexible pattern that handles spaces around 'x'
        pattern = r'(\d+)\s*x\s*(\d+)\s+([\d%-]+)'
        match = re.search(pattern, text)
        
        if match:
            repetitions = int(match.group(1))
            distance = int(match.group(2))
            percentages = match.group(3)
            
            if '-' in percentages:
                percent_list = percentages.split('-')
                if len(percent_list) > 1:
                    for percent in percent_list:
                        percent_clean = percent.replace('%', '').strip()
                        if percent_clean:
                            sets.append({
                                'repetitions': 1,
                                'distanceMeters': distance,
                                'vmaPercent': float(percent_clean),
                                'recoverySeconds': 0,
                                'recoveryType': 'active'
                            })
                else:
                    percent_clean = percent_list[0].replace('%', '').strip()
                    sets.append({
                        'repetitions': repetitions,
                        'distanceMeters': distance,
                        'vmaPercent': float(percent_clean),
                        'recoverySeconds': 0,
                        'recoveryType': 'active'
                    })
            else:
                percent_clean = percentages.replace('%', '').strip()
                sets.append({
                    'repetitions': repetitions,
                    'distanceMeters': distance,
                    'vmaPercent': float(percent_clean),
                    'recoverySeconds': 0,
                    'recoveryType': 'active'
                })
        
        return sets

def validate_json_structure(data: Dict) -> List[str]:
    """Validate the training plan structure and return error messages"""
    errors = []
    
    required_top_level = ['title', 'warmup', 'cooldown', 'remarks', 'groups']
    for field in required_top_level:
        if field not in data:
            errors.append(f"Missing required field: {field}")
    
    if 'groups' in data:
        for i, group in enumerate(data['groups']):
            if 'title' not in group:
                errors.append(f"Group {i} missing title")
            if 'blocks' not in group:
                errors.append(f"Group {i} missing blocks")
            else:
                for j, block in enumerate(group['blocks']):
                    if 'title' not in block:
                        errors.append(f"Block {j} in group {i} missing title")
                    if 'sets' not in block:
                        errors.append(f"Block {j} in group {i} missing sets")
                    else:
                        for k, set_data in enumerate(block['sets']):
                            set_required = ['repetitions', 'vmaPercent', 'recoverySeconds', 'recoveryType']
                            for field in set_required:
                                if field not in set_data:
                                    errors.append(f"Set {k} in block {j}, group {i} missing {field}")
    
    return errors

def stream_main():
    st.title("🏃 Training Plan Converter")
    st.subheader("Convert unstructured training notes to structured JSON")
    
    converter = TrainingPlanConverter()
    
    # Initialize session state
    if 'converted_json' not in st.session_state:
        st.session_state.converted_json = ""
    if 'edited_json' not in st.session_state:
        st.session_state.edited_json = ""
    if 'validation_errors' not in st.session_state:
        st.session_state.validation_errors = []
    
    # Text input
    training_text = st.text_area(
        "Paste your training notes here:",
        height=300,
        value="""Avant  séance (20min)

Échauffement 15' boucle habituelle + 3 gammes  

Contenu de la séance (40 min)

Bloc GROUPE 1  :

Bloc 1

-       3x 1200 75%-80%-85%

2'30'' actif (pour les plus en forme), marche ou trott entre chaque répétition 

Bloc 2

3'min pause sèche 

-       3 x 800 90%

2' actif (pour les plus en forme), marche ou trott entre chaque répétition 

Bloc 3 

-       4 x 200 105%

1' actif (pour les plus en forme), marche ou trott entre chaque répétition 

3'min pause sèche 

Bloc GROUPE 2  :

Bloc 1

-       3x 1000 75%-80%-85%

2'30'' actif (pour les plus en forme), marche ou trott entre chaque répétition 

Bloc 2

3'min pause sèche 

-       3 x 600 90%

2' actif (pour les plus en forme), marche ou trott entre chaque répétition 

Bloc 3 

-       4 x 100 105%

1' actif (pour les plus en forme), marche ou trott entre chaque répétition 

Retour au calme en footing lent autour de la piste dans le sens horlogique 5'

Remarques supplémentaires : 

Bien respecter les % de VMA très important."""
    )
    
    col1, col2 = st.columns(2)
    
    with col1:
        if st.button("🔄 Convert to JSON", use_container_width=True):
            try:
                result = converter.parse_training_notes(training_text)
                json_output = json.dumps(result, indent=2, ensure_ascii=False)
                st.session_state.converted_json = json_output
                st.session_state.edited_json = json_output
                
                # Validate
                errors = validate_json_structure(result)
                st.session_state.validation_errors = errors
                
                if errors:
                    st.error(f"Conversion completed with {len(errors)} validation errors")
                else:
                    st.success("Conversion completed successfully!")
                
            except Exception as e:
                st.error(f"Error during conversion: {str(e)}")
    
    with col2:
        if st.session_state.converted_json:
            if st.download_button(
                label="💾 Download JSON",
                data=st.session_state.edited_json,
                file_name="training_plan.json",
                mime="application/json",
                use_container_width=True
            ):
                st.success("File ready for download!")
    
    # Display editable JSON and preview
    if st.session_state.converted_json:
        st.divider()
        
        # Two columns for JSON editor and preview
        col_edit, col_preview = st.columns(2)
        
        with col_edit:
            st.subheader("✏️ Edit JSON")
            st.caption("Fix any parsing errors in the JSON below")
            
            # Editable JSON text area
            edited_json = st.text_area(
                "Edit JSON output:",
                value=st.session_state.edited_json,
                height=400,
                key="json_editor"
            )
            
            if edited_json != st.session_state.edited_json:
                st.session_state.edited_json = edited_json
                
                # Validate edited JSON
                try:
                    parsed_data = json.loads(edited_json)
                    errors = validate_json_structure(parsed_data)
                    st.session_state.validation_errors = errors
                    
                    if errors:
                        st.error(f"❌ {len(errors)} validation errors found")
                    else:
                        st.success("✅ JSON is valid!")
                        
                except json.JSONDecodeError as e:
                    st.error(f"❌ Invalid JSON: {str(e)}")
            
            # Validation errors
            if st.session_state.validation_errors:
                with st.expander("🔍 Validation Errors", expanded=True):
                    for error in st.session_state.validation_errors:
                        st.error(error)
        
        with col_preview:
            st.subheader("👀 Preview")
            st.caption("Live preview of the training plan")
            
            try:
                parsed_data = json.loads(st.session_state.edited_json)
                
                # Basic info
                st.write(f"**Title:** {parsed_data.get('title', 'N/A')}")
                st.write(f"**Warmup:** {parsed_data.get('warmup', 'N/A')}")
                st.write(f"**Cooldown:** {parsed_data.get('cooldown', 'N/A')}")
                st.write(f"**Remarks:** {parsed_data.get('remarks', 'N/A')}")
                
                # Groups and blocks
                for group in parsed_data.get('groups', []):
                    st.subheader(f"🏁 {group.get('title', 'Untitled Group')}")
                    
                    for block in group.get('blocks', []):
                        st.write(f"**{block.get('title', 'Untitled Block')}**")
                        
                        for set_data in block.get('sets', []):
                            distance = set_data.get('distanceMeters')
                            duration = set_data.get('durationSeconds')
                            if distance:
                                activity = f"{distance}m"
                            elif duration:
                                activity = f"{duration}s"
                            else:
                                activity = "N/A"
                            
                            st.write(
                                f"- {set_data.get('repetitions', '?')}x {activity} "
                                f"at {set_data.get('vmaPercent', '?')}% VMA, "
                                f"{set_data.get('recoverySeconds', '?')}s {set_data.get('recoveryType', '?')} recovery"
                            )
                        
                        if block.get('afterRecoverySeconds'):
                            st.write(
                                f"*Then {block['afterRecoverySeconds']}s "
                                f"{block.get('afterRecoveryType', 'rest')} recovery*"
                            )
                        
                        st.write("")  # Spacing
                
            except json.JSONDecodeError:
                st.error("Cannot preview - invalid JSON")
            except Exception as e:
                st.error(f"Error generating preview: {str(e)}")
        
        # Quick fixes section
        st.divider()
        st.subheader("🔧 Quick Fixes")
        
        col_fix1, col_fix2, col_fix3 = st.columns(3)
        
        with col_fix1:
            if st.button("Fix Recovery Types"):
                try:
                    data = json.loads(st.session_state.edited_json)
                    # Ensure all recovery types are valid
                    valid_types = ['active', 'walk', 'jog', 'rest']
                    for group in data.get('groups', []):
                        for block in group.get('blocks', []):
                            for set_data in block.get('sets', []):
                                current_type = set_data.get('recoveryType', 'rest')
                                if current_type not in valid_types:
                                    set_data['recoveryType'] = 'rest'
                            if 'afterRecoveryType' in block:
                                if block['afterRecoveryType'] not in valid_types:
                                    block['afterRecoveryType'] = 'rest'
                    
                    st.session_state.edited_json = json.dumps(data, indent=2, ensure_ascii=False)
                    st.rerun()
                except:
                    st.error("Could not apply fix")
        
        with col_fix2:
            if st.button("Add Missing Fields"):
                try:
                    data = json.loads(st.session_state.edited_json)
                    # Add any missing required fields with defaults
                    for group in data.get('groups', []):
                        for block in group.get('blocks', []):
                            for set_data in block.get('sets', []):
                                if 'recoveryType' not in set_data:
                                    set_data['recoveryType'] = 'rest'
                                if 'recoverySeconds' not in set_data:
                                    set_data['recoverySeconds'] = 60
                    
                    st.session_state.edited_json = json.dumps(data, indent=2, ensure_ascii=False)
                    st.rerun()
                except:
                    st.error("Could not apply fix")
        
        with col_fix3:
            if st.button("Format JSON"):
                try:
                    data = json.loads(st.session_state.edited_json)
                    st.session_state.edited_json = json.dumps(data, indent=2, ensure_ascii=False)
                    st.rerun()
                except:
                    st.error("Could not format JSON")


def main():
    converter = TrainingPlanConverter()
    
    training_notes = """
Avant  séance (20min)

Échauffement 15' boucle habituelle + 3 gammes  

Contenu de la séance (40 min)

Bloc GROUPE 1  :

Bloc 1

-       3x 1200 75%-80%-85%

2'30'' actif (pour les plus en forme), marche ou trott entre chaque répétition 

Bloc 2

3'min pause sèche 

-       3 x 800 90%

2' actif (pour les plus en forme), marche ou trott entre chaque répétition 

Bloc 3 

-       4 x 200 105%

1' actif (pour les plus en forme), marche ou trott entre chaque répétition 

3'min pause sèche 

Bloc GROUPE 2  :

Bloc 1

-       3x 1000 75%-80%-85%

2'30'' actif (pour les plus en forme), marche ou trott entre chaque répétition 

Bloc 2

3'min pause sèche 

-       3 x 600 90%

2' actif (pour les plus en forme), marche ou trott entre chaque répétition 

Bloc 3 

-       4 x 100 105%

1' actif (pour les plus en forme), marche ou trott entre chaque répétition 

Retour au calme en footing lent autour de la piste dans le sens horlogique 5'

Remarques supplémentaires : 

Bien respecter les % de VMA très important.
    """
    
    # Convert to JSON
    json_output = converter.parse_training_notes(training_notes)
    print("Converted JSON:")
    print(json_output)
if __name__ == "__main__":
    stream_main()