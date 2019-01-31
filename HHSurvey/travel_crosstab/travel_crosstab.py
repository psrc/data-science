import pandas as pd
import math
import numpy as np
from scipy import stats as st

z = 1.96

#trip_detail = pd.read_csv('trip_2017.csv')

#create_cross_tab_with_weights
def cross_tab(var1, var2, wt_field, type):
        print 'reading in data'
        table = pd.read_csv('person_2017.csv')
        print var1
        print var2
        print wt_field
        if type == 'total':
            raw = table.groupby([var1, var2]).count()[wt_field].reset_index()
            raw.columns = [var1, var2, 'sample_count']
            N_hh = table.groupby([var1])['hhid'].nunique().reset_index()
            expanded = table.groupby([var1, var2]).sum()[wt_field].reset_index()
            expanded_tot = expanded.groupby(var1).sum()[wt_field].reset_index()
            expanded.columns = [var1, var2, 'estimate']
            expanded = pd.merge(expanded, expanded_tot, on = var1)
            expanded['share']= expanded['estimate']/expanded[wt_field]
            expanded = pd.merge(expanded,N_hh, on = var1).reset_index()
            expanded['in'] = (expanded['share']*(1-expanded['share']))/expanded['hhid']
            expanded['MOE'] = z*np.sqrt(expanded['in'])
            expanded['N_HH']=expanded['hhid']
            crosstab = pd.merge(raw, expanded, on =[var1, var2]).reset_index()

        if type == 'mean':
            table [var2] = pd.to_numeric(table[var2], errors=coerce)
            table = table.dropna(subset=[var2])
            table = table[(table[var2] !=0)]
            table = table[(table[var2] < 100)]
            table['weighted_total'] = table[wt_field]*table[var2]
            expanded = table.groupby([var1]).sum()['weighted_total'].reset_index()
            expanded_tot = table.groupby([var1]).sum()[wt_field].reset_index()
            expanded_moe = table[[var1,var2]].groupby(var1).agg(['sem'], axis=1).reset_index()
            print expanded
            print expanded_moe
            #expanded.columns = [var1, var2, 'we']
            expanded = pd.merge(expanded, expanded_tot, on = var1)
            expanded = pd.merge(expanded, expanded_moe, on = var1)
            expanded['mean']= expanded['weighted_total']/expanded[wt_field]
            crosstab = expanded

        #cross = cross_tab(person_detail, var1, var2 ,  'hh_wt_revised', 'total')
        #sm_df = cross[[analysis_variable, col, 'share']]
        #sm_df =sm_df.pivot(index=col, columns = analysis_variable, values ='share')
        crosstab= crosstab.pivot(index=var1, columns = var2)[['sample_count', 'estimate', 'share', 'MOE', 'N_HH']]
        return crosstab

def simple_table(table,var2, wt_field, type):
        if type == 'total':
            print var2
            raw = table.groupby(var2).count()[wt_field].reset_index()
            raw.columns =  [var2, 'sample_count']
            N_hh = table.groupby(var2)['hhid'].nunique().reset_index()
            expanded = table.groupby(var2).sum()[wt_field].reset_index()
            expanded_tot = expanded.sum()[wt_field]
            expanded.columns = [var2, 'estimate']
            #expanded = pd.merge(expanded, expanded_tot, on = var2)
            expanded['share']= expanded['estimate']/expanded_tot
            expanded = pd.merge(expanded,N_hh, on = var2).reset_index()
            expanded['in'] = (expanded['share']*(1-expanded['share']))/expanded['hhid']
            expanded['N_HH']=expanded['hhid']
            expanded['MOE'] = z*np.sqrt(expanded['in'])
            s_table = pd.merge(raw, expanded, on =var2).reset_index()

        return s_table
