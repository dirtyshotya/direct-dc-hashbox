#!/usr/bin/env python3

import cgi
import cgitb
import csv

cgitb.enable()

form = cgi.FieldStorage()

# Extract form data
settings = form.getvalue('settings')
battery_level = form.getvalue('batteryLevel')
charge_rate = form.getvalue('chargeRate')

# Save the form data to a CSV file or use it directly in the application
with open('/home/100acresranch/settings.csv', 'w', newline='') as csvfile:
    fieldnames = ['settings', 'batteryLevel', 'chargeRate']
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)

    writer.writeheader()
    writer.writerow({'settings': settings, 'batteryLevel': battery_level, 'chargeRate': charge_rate})

print("Content-type: text/html\n")
print("<html><body>")
print("<h1>Settings saved successfully!</h1>")
print("</body></html>")
