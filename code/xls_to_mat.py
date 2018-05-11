import gdxpds
import pandas as pds
import numpy as np
import sys
from scipy.io import savemat



data_dict = {}
file = r'29nodes_simplified_input.xlsx'

### Parameters
# Parameter r
r = pds.read_excel(file, sheet_name="Lines", skiprows=None, skip_footer=0, usecols=[4], names=["Value"]).as_matrix()
data_dict['r'] = r
# Parameter x
x = pds.read_excel(file, sheet_name="Lines", skiprows=None, skip_footer=0, usecols=[5], names=["Value"]).as_matrix()
data_dict['x'] = x
# Parameter Ilimit
I_up = pds.read_excel(file, sheet_name="Lines", skiprows=None, skip_footer=0, usecols=[6], names=["Value"]).as_matrix()
data_dict['I_up'] = I_up
# Parameter Vmin
Vmin = pds.read_excel(file, sheet_name="Nodes", skiprows=None, skip_footer=0, usecols=[3], names=["Value"]).as_matrix()
data_dict['Vmin'] = Vmin
# Parameter Vmax
Vmax = pds.read_excel(file, sheet_name="Nodes", skiprows=None, skip_footer=0, usecols=[4], names=["Value"]).as_matrix()
data_dict['Vmax'] = Vmax
# Parameter pDemand
pDemand = pds.read_excel(file, sheet_name="DemandProfiles", skiprows=None, skip_footer=0, usecols="B:E").as_matrix()[1:]
data_dict['pDemand'] = pDemand
# Parameter qDemand
qDemand = pds.read_excel(file, sheet_name="QDemandProfiles", skiprows=None, skip_footer=0, usecols="B:E").as_matrix()[1:]
data_dict['qDemand'] = qDemand
# Parameter pDemandAverage
pDemandAverage = pds.read_excel(file, sheet_name="DemandAverage", skiprows=None, skip_footer=0, usecols="B:E").as_matrix()[1:]
data_dict['pDemandAverage'] = pDemandAverage
# Parameter pSolarMax
pSolarMax = pds.read_excel(file, sheet_name="SolarProfiles", skiprows=None, skip_footer=0, usecols="B:E").as_matrix()[1:]
data_dict['pSolarMax'] = pSolarMax
# Parameter pSolarMaxAverage
pSolarMaxAverage = pds.read_excel(file, sheet_name="SolarAverage", skiprows=None, skip_footer=0, usecols="B:E").as_matrix()[1:]
data_dict['pSolarMaxAverage'] = pSolarMaxAverage

savemat('data_4nodes.mat', data_dict)