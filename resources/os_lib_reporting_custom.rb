require 'json'

module OsLib_Reporting

  # setup - get model, sql, and setup web assets path
  def self.setup(runner)
    results = {}

    # get the last model
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError('Cannot find last model.')
      return false
    end
    model = model.get

    # get the last idf
    workspace = runner.lastEnergyPlusWorkspace
    if workspace.empty?
      runner.registerError('Cannot find last idf file.')
      return false
    end
    workspace = workspace.get

    # get the last sql file
    sqlFile = runner.lastEnergyPlusSqlFile
    if sqlFile.empty?
      runner.registerError('Cannot find last sql file.')
      return false
    end
    sqlFile = sqlFile.get
    model.setSqlFile(sqlFile)

    # populate hash to pass to measure
    results[:model] = model
    # results[:workspace] = workspace
    results[:sqlFile] = sqlFile
    results[:web_asset_path] = OpenStudio.getSharedResourcesPath / OpenStudio::Path.new('web_assets')

    return results
  end

  # developer notes
  # - Other thant the 'setup' section above this file should contain methods (def) that create sections and or tables.
  # - Any method that has 'section' in the name will be assumed to define a report section and will automatically be
  # added to the table of contents in the report.
  # - Any section method should have a 'name_only' argument and should stop the method if this is false after the
  # section is defined.
  # - Generally methods that make tables should end with '_table' however this isn't critical. What is important is that
  # it doesn't contain 'section' in the name if it doesn't return a section to the measure.
  # - The data below would typically come from the model or simulation results, but can also come from elsewhere or be
  # defeined in the method as was done with these examples.
  # - You can loop through objects to make a table for each item of that type, such as air loops


  
  # JWT_01 Code start
    # create template section

	
	# jwt first table build
  # create table for exterior lights
  def self.eflh_section(model, sqlFile, runner, name_only = false)
    # End Uses from output table
    eflh_data = {}
    eflh_data[:title] = ''
    eflh_data[:header] = ['Description', 'Total Power', 'Annual Consumption', 'EFLH']
    power_units = 'W'
    consumption_units = 'kWh'
    eflh_data[:units] = ['', power_units, consumption_units, '']
    eflh_data[:data] = []

    # gather data for section
    @eflh_section = {}
    @eflh_section[:title] = 'IL TRM ELFH Section'

    # stop here if only name is requested this is used to populate display name for arguments
    if name_only == true
      return @eflh_section
    end
# JWT 02 Start to intial query for EFLH of exterior lighting
    query0 = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='LightingSummary' and TableName='Exterior Lighting'  and RowName='Exterior Lighting Total' and ColumnName='Total Watts'"
    query1 = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='LightingSummary' and TableName='Exterior Lighting'  and RowName='Exterior Lighting Total' and ColumnName='Consumption'"
    extlight_total_watts = sqlFile.execAndReturnFirstDouble(query0)
    extlight_consumption = sqlFile.execAndReturnFirstDouble(query1)
    if extlight_total_watts.empty? || extlight_consumption.empty?
      runner.registerWarning('Did not find value for Exterior Lighting Total.')
      return false
    else
      # add data
      extlight_total_watts_ip = extlight_total_watts.get
      extlight_consumption_si = extlight_consumption.get
	  source_units = 'GJ'
	  target_units = 'kWh'
	  #convert si to ip
	  extlight_consumption_ip = OpenStudio.convert(extlight_consumption_si, source_units, target_units).get
	  #consumption_ip = OpenStudio.convert(sqlFile.netSiteEnergy.get,'GJ','kWh').get
      extlight_total_watts_ip_neat = OpenStudio.toNeatString(extlight_total_watts_ip, 2, true)
      extlight_consumption_ip_neat = OpenStudio.toNeatString(extlight_consumption_ip, 2, true)
	  extlight_eflh = (extlight_consumption_ip / extlight_total_watts_ip) * 1000
	  extlight_eflh_neat = OpenStudio.toNeatString(extlight_eflh, 0, true)
	  #eflh = consumption_ip_neat / total_watts_ip_neat
      eflh_data[:data] << ['Exterior Lighting Total', extlight_total_watts_ip_neat, extlight_consumption_ip_neat, extlight_eflh_neat]
      runner.registerValue('exterior_lighting_total_power', extlight_total_watts_ip, power_units)
      runner.registerValue('exterior_lighting_total_consumption', extlight_consumption_ip, consumption_units)
    end

# JWT 03 Build a query to get the cooling eflh use the Eplus report
	# This part pulls from the ABUPS report for total energy
	query2 = 'SELECT Value FROM tabulardatawithstrings WHERE '
	query2 << "ReportName='EnergyMeters' and "
	query2 << "ReportForString='Entire Facility' and "
	query2 << "TableName='Annual and Peak Values - Electricity' and "
	query2 << "RowName='Cooling:Electricity' and "
	query2 << "ColumnName='Electricity Annual Value' and "
	query2 << "Units='GJ';"
    cooling_energy = sqlFile.execAndReturnFirstDouble(query2)
	
	source_units = "GJ"
	target_units = "kWh"

# conversion	
	cooling_total_energy_ip = OpenStudio.convert(cooling_energy.get, source_units, target_units).get
	
# JWT 04 for heating
	query4 = 'SELECT Value FROM tabulardatawithstrings WHERE '
	query4 << "ReportName='EnergyMeters' and "
	query4 << "ReportForString='Entire Facility' and "
	query4 << "TableName='Annual and Peak Values - Electricity' and "
	query4 << "RowName='Heating:Electricity' and "
	query4 << "ColumnName='Electricity Annual Value' and " 
	query4 << "Units='GJ';"
    heating_elec_energy = sqlFile.execAndReturnFirstDouble(query4)
	
	#conversion
	heating_elec_energy_ip = OpenStudio.convert(heating_elec_energy.get, source_units, target_units).get
	
	if cooling_energy.empty?
	runner.registerWarning('Did not find value for Cooling Energy.')
	return false
	else
	
	# if heating_energy.empty?
	# runner.registerWarning('Did not find value for Heating Energy.')
	# return false
	# else
		
	# This part pulls from the Energy Meters Report
	query3 = 'SELECT Value FROM tabulardatawithstrings WHERE '
	query3 << "ReportName='EnergyMeters' and "
	query3 << "ReportForString='Entire Facility' and "
	query3 << "TableName='Annual and Peak Values - Electricity' and "
	query3 << "RowName='Cooling:Electricity' and "
	query3 << "ColumnName='Electricity Maximum Value' and "
	query3 << "Units='W';"
	cooling_total_power = sqlFile.execAndReturnFirstDouble(query3)

	# This part pulls from the Energy Meters Report
	query5 = 'SELECT Value FROM tabulardatawithstrings WHERE '
	query5 << "ReportName='EnergyMeters' and "
	query5 << "ReportForString='Entire Facility' and "
	query5 << "TableName='Annual and Peak Values - Electricity' and "
	query5 << "RowName='Heating:Electricity' and "
	query5 << "ColumnName='Electricity Maximum Value' and "
	query5 << "Units='W';"
	heating_elec_power = sqlFile.execAndReturnFirstDouble(query5)
		
	# Heating Gas
	query6 = 'SELECT Value FROM tabulardatawithstrings WHERE '
	query6 << "ReportName='EnergyMeters' and "
	query6 << "ReportForString='Entire Facility' and "
	query6 << "TableName='Annual and Peak Values - Gas' and "
	query6 << "RowName='Heating:Gas' and "
	query6 << "ColumnName='Gas Annual Value' and " 
	query6 << "Units='GJ';"
    heating_gas_energy = sqlFile.execAndReturnFirstDouble(query6)
	
		#conversion
	heating_gas_energy_ip = OpenStudio.convert(heating_gas_energy.get, source_units, target_units).get
	
	
	# This part pulls from the Energy Meters Report
	query7 = 'SELECT Value FROM tabulardatawithstrings WHERE '
	query7 << "ReportName='EnergyMeters' and "
	query7 << "ReportForString='Entire Facility' and "
	query7 << "TableName='Annual and Peak Values - Gas' and "
	query7 << "RowName='Heating:Gas' and "
	query7 << "ColumnName='Gas Maximum Value' and "
	query7 << "Units='W';"
	heating_gas_power = sqlFile.execAndReturnFirstDouble(query7)
	
	if cooling_total_power.empty?
	runner.registerWarning('Did not find value for Cooling Power.')
	return false
	else

	#get some more variables and ignore OS results report
	query8 = 'SELECT Value FROM tabulardatawithstrings WHERE '
	query8 << "ReportName='SourceEnergyEndUseComponentsSummary' and "
	query8 << "ReportForString='Entire Facility' and "
	query8 << "TableName='Source Energy End Use Components Summary' and "
	query8 << "RowName='Total Source Energy End Use Components' and "
	query8 << "ColumnName='Source Electricity' and "
	query8 << "Units='GJ';"
	bldg_elec = sqlFile.execAndReturnFirstDouble(query8)
	
	bldg_elec_ip = OpenStudio.convert(bldg_elec.get, source_units, target_units).get
	
	query9 = 'SELECT Value FROM tabulardatawithstrings WHERE '
	query9 << "ReportName='SourceEnergyEndUseComponentsSummary' and "
	query9 << "ReportForString='Entire Facility' and "
	query9 << "TableName='Source Energy End Use Components Summary' and "
	query9 << "RowName='Total Source Energy End Use Components' and "
	query9 << "ColumnName='Source Natural Gas' and "
	query9 << "Units='GJ';"
	bldg_gas = sqlFile.execAndReturnFirstDouble(query9)
	
	bldg_gas_ip = OpenStudio.convert(bldg_gas.get, source_units, target_units).get
	
	
	# total building area
    query10 = 'SELECT Value FROM tabulardatawithstrings WHERE '
    query10 << "ReportName='AnnualBuildingUtilityPerformanceSummary' and "
    query10 << "ReportForString='Entire Facility' and "
    query10 << "TableName='Building Area' and "
    query10 << "RowName='Total Building Area' and "
    query10 << "ColumnName='Area' and "
    query10 << "Units='m2';"
    bldg_area = sqlFile.execAndReturnFirstDouble(query10)
	
	s_area_units = 'm^2'
    t_area_units = 'ft^2'
	
	bldg_area_ip = OpenStudio.convert(bldg_area.get, s_area_units, t_area_units).get
	
	# add a query for the energy transfer numbers in the meter requests
	query11 = 'SELECT Value FROM tabulardatawithstrings WHERE '
	query11 << "ReportName='EnergyMeters' and "
	query11 << "ReportForString='Entire Facility' and "
	query11 << "TableName='Annual and Peak Values - Other' and "
	query11 << "RowName='Heating:EnergyTransfer' and "
	query11 << "ColumnName='Maximum Value' and "
	query11 << "Units='W';"
	heating_et_max = sqlFile.execAndReturnFirstDouble(query11)
	
	query12 = 'SELECT Value FROM tabulardatawithstrings WHERE '
	query12 << "ReportName='EnergyMeters' and "
	query12 << "ReportForString='Entire Facility' and "
	query12 << "TableName='Annual and Peak Values - Other' and "
	query12 << "RowName='Heating:EnergyTransfer' and "
	query12 << "ColumnName='Annual Value' and "
	query12 << "Units='GJ';"
	heating_et_annual = sqlFile.execAndReturnFirstDouble(query12)
	
	heating_et_annual_ip = OpenStudio.convert(heating_et_annual.get, source_units, target_units).get
	
	
		# add a query for the energy transfer numbers in the meter requests
	query13 = 'SELECT Value FROM tabulardatawithstrings WHERE '
	query13 << "ReportName='EnergyMeters' and "
	query13 << "ReportForString='Entire Facility' and "
	query13 << "TableName='Annual and Peak Values - Other' and "
	query13 << "RowName='Cooling:EnergyTransfer' and "
	query13 << "ColumnName='Maximum Value' and "
	query13 << "Units='W';"
	cooling_et_max = sqlFile.execAndReturnFirstDouble(query13)
	
	query14 = 'SELECT Value FROM tabulardatawithstrings WHERE '
	query14 << "ReportName='EnergyMeters' and "
	query14 << "ReportForString='Entire Facility' and "
	query14 << "TableName='Annual and Peak Values - Other' and "
	query14 << "RowName='Cooling:EnergyTransfer' and "
	query14 << "ColumnName='Annual Value' and "
	query14 << "Units='GJ';"
	cooling_et_annual = sqlFile.execAndReturnFirstDouble(query14)
	
	cooling_et_annual_ip = OpenStudio.convert(cooling_et_annual.get, source_units, target_units).get
	
	#Do the unit conversions, clean up, and the arithmetic for EFLH
	
	#conversion
		#I made a couple of attempts at the conversion function before I picked up on the .get function
	#cooling_total_energy_ip = OpenStudio.convert(cooling_total_energy, 'GJ', 'kWh').get
	#cooling_total_energy_ip = (cooling_total_energy / 277.8) # One GJ has 277.8 kWH 
		#cooling_total_energy_ip = cooling_total_energy
	# cleaning
		cooling_total_energy_ip_neat = OpenStudio.toNeatString(cooling_total_energy_ip, 2, true)
		cooling_total_power_neat = OpenStudio.toNeatString(cooling_total_power.get, 2, true)
		heating_elec_energy_ip_neat = OpenStudio.toNeatString(heating_elec_energy_ip, 2, true)
		heating_elec_power_neat = OpenStudio.toNeatString(heating_elec_power.get, 2, true)
		heating_gas_energy_ip_neat = OpenStudio.toNeatString(heating_gas_energy_ip, 2, true)
		heating_gas_power_neat = OpenStudio.toNeatString(heating_gas_power.get, 2, true)
		bldg_elec_ip_neat = OpenStudio.toNeatString(bldg_elec_ip, 2, true)
		bldg_gas_ip_neat = OpenStudio.toNeatString(bldg_gas_ip, 2, true)
		heating_et_max_neat = OpenStudio.toNeatString(heating_et_max.get, 2, true)
		heating_et_annual_neat = OpenStudio.toNeatString(heating_et_annual_ip, 2, true)
		cooling_et_max_neat = OpenStudio.toNeatString(cooling_et_max.get, 2, true)
		cooling_et_annual_neat = OpenStudio.toNeatString(cooling_et_annual_ip, 2, true)
		
		
	#arithmetic
		cooling_eflh = (cooling_total_energy_ip / cooling_total_power.get) * 1000
		cooling_eflh_neat = OpenStudio.toNeatString(cooling_eflh, 1, true)
		if heating_elec_energy_ip == 0
			heating_elec_eflh = 0
			else heating_elec_eflh = (heating_elec_energy_ip / heating_elec_power.get) * 1000
			end
		heating_elec_eflh_neat = OpenStudio.toNeatString(heating_elec_eflh, 1, true)
		if heating_gas_energy_ip == 0
			heating_gas_eflh = 0
			else heating_gas_eflh = (heating_gas_energy_ip / heating_gas_power.get) * 1000
		    end
		heating_gas_eflh_neat = OpenStudio.toNeatString(heating_gas_eflh, 1, true)
		heating_et_eflh = (heating_et_annual_ip / heating_et_max.get) * 1000
		cooling_et_eflh = (cooling_et_annual_ip / cooling_et_max.get) * 1000
		
		#cleaning energy transfer EFLHs
		heating_et_eflh_neat = OpenStudio.toNeatString(heating_et_eflh, 1, true)
		cooling_et_eflh_neat = OpenStudio.toNeatString(cooling_et_eflh, 1, true)
		
	# add in hard coded 99.5 percentile values for heating and cooling EFLH based on the heating:gas and cooling:electricity energy meters
	# for midrise appt these are: C:0.8191 and H:0.8822
	
	cool_derate = 0.8191
	heat_derate = 0.8822
	
		htg_derate_power = heating_gas_power.get * heat_derate
		clg_derate_power = cooling_total_power.get * cool_derate
		htg_derate_power_neat = OpenStudio.toNeatString(htg_derate_power, 1, true)
		clg_derate_power_neat = OpenStudio.toNeatString(clg_derate_power, 1, true)
	
		clg_derate_eflh = (cooling_total_energy_ip / clg_derate_power) * 1000
		clg_derate_eflh_neat = OpenStudio.toNeatString(clg_derate_eflh, 1, true)
		
		htg_derate_eflh = (heating_gas_energy_ip / htg_derate_power) * 1000
		htg_derate_eflh_neat = OpenStudio.toNeatString(htg_derate_eflh, 1, true)
		
		
		
	# add data
	eflh_data[:data] << ['Cooling', cooling_total_power_neat, cooling_total_energy_ip_neat, cooling_eflh_neat]
	eflh_data[:data] << ['Heating Electricity', heating_elec_power_neat, heating_elec_energy_ip_neat, heating_elec_eflh_neat]
	eflh_data[:data] << ['Heating Gas', heating_gas_power_neat, heating_gas_energy_ip_neat, heating_gas_eflh_neat]
	eflh_data[:data] << ['Building Elec', 'N/A', bldg_elec_ip_neat, 'N/A']
	eflh_data[:data] << ['Building Gas', 'N/A', bldg_gas_ip_neat, 'N/A']
	eflh_data[:data] << ['Building Area', 'N/A', bldg_area_ip, 'sqft']
	eflh_data[:data] << ['Heating:EnergyTransfer', heating_et_max_neat, heating_et_annual_neat, heating_et_eflh_neat]
	eflh_data[:data] << ['Cooling:EnergyTransfer', cooling_et_max_neat, cooling_et_annual_neat, cooling_et_eflh_neat]
	eflh_data[:data] << ['Heating Gas Derated', htg_derate_power_neat, heating_gas_energy_ip_neat, htg_derate_eflh_neat]
	eflh_data[:data] << ['Cooling Derated', clg_derate_power_neat, cooling_total_energy_ip_neat, clg_derate_eflh_neat]
	

	# This code chunk is key to working in the PAT. This takes a specific datapoint result variable and sends it back our to be aggregated with the cloud results
	  runner.registerValue('cooling_eflh',cooling_eflh)
      runner.registerValue('heating_elec_eflh',heating_elec_eflh)
	  runner.registerValue('heating_gas_eflh',heating_gas_eflh)
	  runner.registerValue('heating_elec_energy',heating_elec_energy_ip)
	  runner.registerValue('heating_elec_power',heating_elec_power.get)
	  runner.registerValue('heating_gas_energy',heating_gas_energy_ip)
	  runner.registerValue('heating_gas_power',heating_gas_power.get)
	  runner.registerValue('cooling_total_energy',cooling_total_energy_ip)
	  runner.registerValue('cooling_total_power',cooling_total_power.get)
	  runner.registerValue('bldg_elec',bldg_elec_ip)
	  runner.registerValue('bldg_gas',bldg_gas_ip)
	  runner.registerValue('bldg_area',bldg_area_ip)
	  runner.registerValue('heating_et_power_W',heating_et_max.get)
	  runner.registerValue('heating_et_annual_kWh',heating_et_annual_ip)
	  runner.registerValue('heating_et_eflh',heating_et_eflh)
	  runner.registerValue('cooling_et_power_W',cooling_et_max.get)
	  runner.registerValue('cooling_et_annual_kWh',cooling_et_annual_ip)
	  runner.registerValue('cooling_et_eflh',cooling_et_eflh)
	  runner.registerValue('clg_derate_eflh',clg_derate_eflh)
	  runner.registerValue('htg_derate_eflh',htg_derate_eflh)
	  
	end
	
	
	# This was an attempt at building the output vector ie parrallel axis plot axis but this needs to live out in the measure.rb and the runner.register used to communicate outward
	#def outputs
	# #define cooling_eflh as a output for objective function in OS
	# eflhresults = OpenStudio::Measure::OSOutputVector.new
	# eflhresults << OpenStudio::Measure::OSOutput.makeDoubleOutput(cooling_eflh) #hrs
	# eflhresults << OpenStudio::Measure::OSOutput.makeDoubleOutput(heating_eflh) #hrs
	# return eflhresults
	
	
    # don't create empty table
    if extlight_total_watts.to_f > 0 || extlight_consumption.to_f > 0
      @eflh_section[:tables] = [eflh_data] # only one table for this section
    else
      @eflh_section[:tables] = []
    end

    return @eflh_section
  end
	 
end 
  
 end