import os

# 
# Use this script to changes to the locust.py file prior to patching them.
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

# Going to insert task above this task and disable this one
orig_text1 = indent8sp + 'async def open_cart_page_and_change_currency(self, page: PageWithRetry):'

# Keeping this task but applying Dan's patch
orig_text2 = indent12sp + 'with self.tracer.start_as_current_span("browser_add_to_cart", context=Context()):'

orig_text3 = indent20sp + 'await page.click(\'p:has-text("Roof Binoculars")\')'

#
# Changes
#

new_text1 =  indent8sp + 'async def open_product_detail_page(self, page: PageWithRetry):\n'
new_text1 += indent12sp + 'tracer = trace.get_tracer(__name__)\n'
new_text1 += indent12sp + 'with tracer.start_as_current_span("browser_pdp", context=Context()):\n'
new_text1 += indent16sp + 'try:\n'
new_text1 += indent20sp + 'page.on("console", lambda msg: print(msg.text))\n'
new_text1 += indent20sp + 'await page.route(\'**/*\', add_baggage_header)\n'
new_text1 += indent20sp + 'await page.goto("/product/HQTGWGPNH4", wait_until="domcontentloaded")\n'                 
new_text1 += indent20sp + 'await page.wait_for_event(\n'
new_text1 += indent24sp + '"response",\n'
new_text1 += indent24sp + 'predicate=lambda r: \'/images/products/thecometbook.jpg\' in r.url and r.status == 200,\n'
new_text1 += indent24sp + 'timeout=15000\n'
new_text1 += indent20sp + ')\n'
new_text1 += indent20sp + 'await page.wait_for_timeout(2000)  # giving the browser time to export the traces\n'
new_text1 += indent20sp + 'logging.info("Product page visited successfully")\n'
new_text1 += indent16sp + 'except Exception as e:\n'
new_text1 += indent20sp + 'logging.error(f"Error in product page visit: {str(e)}")\n'
new_text1 += '\n'
new_text1 += indent8sp + '# @task\n'
new_text1 += indent8sp + '@pw\n'
new_text1 += indent8sp + 'async def open_cart_page_and_change_currency(self, page: PageWithRetry):\n'
new_text1 += indent12sp + 'tracer = trace.get_tracer(__name__)'

new_text2 = indent12sp + 'tracer = trace.get_tracer(__name__)\n'
new_text2 += indent12sp + 'with tracer.start_as_current_span("browser_add_to_cart", context=Context()):'

new_text3 = indent20sp + 'await page.wait_for_event(\n'
new_text3 += indent24sp + '"response",\n'
new_text3 += indent24sp + 'predicate=lambda r: \'/images/products/RoofBinoculars.jpg\' in r.url and r.status == 200,\n'
new_text3 += indent24sp + 'timeout=15000\n'
new_text3 += indent20sp + ')\n'
new_text3 += indent20sp + 'await page.click(\'p:has-text("Roof Binoculars")\')'

# Define your replacements here: { "Target Text": "Replacement Text" }
REPLACEMENTS_MAP = {
    orig_text1 : new_text1,
    orig_text2 : new_text2,
    orig_text3 : new_text3
}

if __name__ == "__main__":
    update_locustfile(SOURCE, DESTINATION, REPLACEMENTS_MAP)