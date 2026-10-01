import os

#
# Use this script to test changes to the locust.py file prior to patching them.
# Apply your changes here, run the script, and review the output in ../../tmp
#

def update_locustfile(source_path, dest_path, replacements):
    """
    Reads a locustfile, applies multiple text replacements,
    and saves the result to a new file.
    """
    if not os.path.exists(source_path):
        print(f"Error: The file '{source_path}' was not found.")
        return

    try:
        # Read the original content
        with open(source_path, 'r', encoding='utf-8') as file:
            content = file.read()

        # Apply each replacement in the dictionary
        for old_text, new_text in replacements.items():
            content = content.replace(old_text, new_text)

        # Write the updated content to the new file
        with open(dest_path, 'w', encoding='utf-8') as file:
            file.write(content)

        print(f"Successfully updated '{source_path}' and saved as '{dest_path}'.")

    except Exception as e:
        print(f"An unexpected error occurred: {e}")

# --- Configuration ---
SOURCE = '../../src/load-generator/locustfile.py'
DESTINATION = '../../tmp/locustfile-modified.py'

# Indent vars
indent4sp = '    '
indent8sp = indent4sp+indent4sp
indent12sp = indent4sp+indent8sp
indent16sp = indent8sp+indent8sp
indent20sp = indent16sp+indent4sp
indent24sp = indent16sp+indent8sp

#
# Original text sections
#

# Remove __init__ entirely since it only set self.tracer which is no longer needed
orig_text0 =  indent8sp + 'def __init__(self, *args, **kwargs):\n'
orig_text0 += indent12sp + 'super().__init__(*args, **kwargs)\n'
orig_text0 += indent12sp + 'self.tracer = trace.get_tracer(__name__)\n'
orig_text0 += '\n'

# Replace self.tracer with local tracer in browser_change_currency span
orig_text1 = indent12sp + 'with self.tracer.start_as_current_span("browser_change_currency", context=Context()):'

# Replace self.tracer with local tracer in browser_add_to_cart span
orig_text2 = indent12sp + 'with self.tracer.start_as_current_span("browser_add_to_cart", context=Context()):'

# Add wait_for_event for product image before and after clicking Roof Binoculars
orig_text3 =  indent20sp + 'await page.click(\'p:has-text("Roof Binoculars")\')\n'
orig_text3 += indent20sp + 'await page.wait_for_load_state("domcontentloaded")\n'
orig_text3 += indent20sp + 'await page.click(\'button:has-text("Add To Cart")\')'

#
# Changes
#

new_text0 = ''

new_text1 =  indent12sp + 'tracer = trace.get_tracer(__name__)\n'
new_text1 += indent12sp + 'with tracer.start_as_current_span("browser_change_currency", context=Context()):'

new_text2 =  indent12sp + 'tracer = trace.get_tracer(__name__)\n'
new_text2 += indent12sp + 'with tracer.start_as_current_span("browser_add_to_cart", context=Context()):'

new_text3 =  indent20sp + 'await page.wait_for_event(\n'
new_text3 += indent24sp + '"response",\n'
new_text3 += indent24sp + 'predicate=lambda r: \'/images/products/RoofBinoculars.jpg\' in r.url and r.status == 200,\n'
new_text3 += indent24sp + 'timeout=15000\n'
new_text3 += indent20sp + ')\n'
new_text3 += indent20sp + 'await page.click(\'p:has-text("Roof Binoculars")\')\n'
new_text3 += indent20sp + 'await page.wait_for_load_state("domcontentloaded")\n'
new_text3 += indent20sp + 'await page.wait_for_event(\n'
new_text3 += indent24sp + '"response",\n'
new_text3 += indent24sp + 'predicate=lambda r: \'/images/products/RoofBinoculars.jpg\' in r.url and r.status == 200,\n'
new_text3 += indent24sp + 'timeout=15000\n'
new_text3 += indent20sp + ')\n'
new_text3 += indent20sp + 'await page.click(\'button:has-text("Add To Cart")\')'

# Define your replacements here: { "Target Text": "Replacement Text" }
REPLACEMENTS_MAP = {
    orig_text0 : new_text0,
    orig_text1 : new_text1,
    orig_text2 : new_text2,
    orig_text3 : new_text3
}

if __name__ == "__main__":
    update_locustfile(SOURCE, DESTINATION, REPLACEMENTS_MAP)
