require 'erb'
require 'json'

require "#{File.dirname(__FILE__)}/resources/os_lib_reporting_custom"
require "#{File.dirname(__FILE__)}/resources/os_lib_helper_methods"

# start the measure
class ILTRMReportMidriseApt < OpenStudio::Ruleset::ReportingUserScript
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return "IL TRM Report_MidriseApt"
  end
  # human readable description
  def description
    return "records as output EnergyTransfer data from the eplustbl.html

These reports are built to be bldg type specfic as a quick work around for derating the EFLH based on 99.5% percentile on heating and cooling peak values.  "
  end
  # human readable description of modeling approach
  def modeler_description
    return "This tries to pull a end use total and peak and build a report"
  end
  def possible_sections

    # methods for sections in order that they will appear in report
    result = []

	result << 'eflh_section'
	
    # # instead of hand populating, any methods with 'section' in the name will be added in the order they appear
    # all_setions =  OsLib_Reporting.methods(false)
    # all_setions.each do |section|
      # next if not section.to_s.include? 'section'
      # result << section.to_s
    # end

    result
  end

  # define the arguments that the user will input
  def arguments
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # populate arguments
    possible_sections.each do |method_name|
      # get display name
      arg = OpenStudio::Ruleset::OSArgument.makeBoolArgument(method_name, true)
      display_name = eval("OsLib_Reporting.#{method_name}(nil,nil,nil,true)[:title]")
      arg.setDisplayName(display_name)
      arg.setDefaultValue(true)
      args << arg
    end

    args
  end # end the arguments method

  # add any outout variable requests here
  def energyPlusOutputRequests(runner, user_arguments)
    super(runner, user_arguments)

    result = OpenStudio::IdfObjectVector.new

    result
  end

  #JWT add in output variables
  def outputs
	#define cooling_eflh as a output for objective function in OS
	eflhresults = OpenStudio::Measure::OSOutputVector.new
	eflhresults << OpenStudio::Measure::OSOutput.makeDoubleOutput('cooling_eflh') #hrs
	eflhresults << OpenStudio::Measure::OSOutput.makeDoubleOutput('heating_elec_eflh') #hrs
	eflhresults << OpenStudio::Measure::OSOutput.makeDoubleOutput('heating_gas_eflh')
	eflhresults << OpenStudio::Measure::OSOutput.makeDoubleOutput('heating_elec_energy')
	eflhresults << OpenStudio::Measure::OSOutput.makeDoubleOutput('heating_elec_power')
	eflhresults << OpenStudio::Measure::OSOutput.makeDoubleOutput('heating_gas_energy')
	eflhresults << OpenStudio::Measure::OSOutput.makeDoubleOutput('heating_gas_power')
	eflhresults << OpenStudio::Measure::OSOutput.makeDoubleOutput('cooling_total_energy')
	eflhresults << OpenStudio::Measure::OSOutput.makeDoubleOutput('cooling_total_power')
	eflhresults << OpenStudio::Measure::OSOutput.makeDoubleOutput('bldg_elec')
	eflhresults << OpenStudio::Measure::OSOutput.makeDoubleOutput('bldg_gas')
	eflhresults << OpenStudio::Measure::OSOutput.makeDoubleOutput('bldg_area')
	eflhresults << OpenStudio::Measure::OSOutput.makeDoubleOutput('heating_et_power_W')
	eflhresults << OpenStudio::Measure::OSOutput.makeDoubleOutput('heating_et_annual_kWh')
	eflhresults << OpenStudio::Measure::OSOutput.makeDoubleOutput('heating_et_eflh')
	eflhresults << OpenStudio::Measure::OSOutput.makeDoubleOutput('cooling_et_power_W')
	eflhresults << OpenStudio::Measure::OSOutput.makeDoubleOutput('cooling_et_annual_kWh')
	eflhresults << OpenStudio::Measure::OSOutput.makeDoubleOutput('cooling_et_eflh')
	eflhresults << OpenStudio::Measure::OSOutput.makeDoubleOutput('clg_derate_eflh')
	eflhresults << OpenStudio::Measure::OSOutput.makeDoubleOutput('htg_derate_eflh')
	
		return eflhresults
end
  
  # define what happens when the measure is run
  def run(runner, user_arguments)
    super(runner, user_arguments)

    # get sql, model, and web assets
    setup = OsLib_Reporting.setup(runner)
    unless setup
      return false
    end
    model = setup[:model]
    # workspace = setup[:workspace]
    sql_file = setup[:sqlFile]
    web_asset_path = setup[:web_asset_path]

    # assign the user inputs to variables
    args = OsLib_HelperMethods.createRunVariables(runner, model, user_arguments, arguments)
    unless args
      return false
    end

    # reporting final condition
    runner.registerInitialCondition('Gathering data from EnergyPlus SQL file and OSM model.')

    # pass measure display name to erb
    @name = name

    # create a array of sections to loop through in erb file
    @sections = []

    # generate data for requested sections
    sections_made = 0
    possible_sections.each do |method_name|

      begin
        next unless args[method_name]
        section = false
        eval("section = OsLib_Reporting.#{method_name}(model,sql_file,runner,false)")
        display_name = eval("OsLib_Reporting.#{method_name}(nil,nil,nil,true)[:title]")
        if section
          @sections << section
          sections_made += 1
          # look for emtpy tables and warn if skipped because returned empty
          section[:tables].each do |table|
            if not table
              runner.registerWarning("A table in #{display_name} section returned false and was skipped.")
              section[:messages] = ["One or more tables in #{display_name} section returned false and was skipped."]
            end
          end
        else
          runner.registerWarning("#{display_name} section returned false and was skipped.")
          section = {}
          section[:title] = "#{display_name}"
          section[:tables] = []
          section[:messages] = []
          section[:messages] << "#{display_name} section returned false and was skipped."
          @sections << section
        end
      rescue => e
        display_name = eval("OsLib_Reporting.#{method_name}(nil,nil,nil,true)[:title]")
        if display_name == nil then display_name == method_name end
        runner.registerWarning("#{display_name} section failed and was skipped because: #{e}. Detail on error follows.")
        runner.registerWarning("#{e.backtrace.join("\n")}")

        # add in section heading with message if section fails
        section = eval("OsLib_Reporting.#{method_name}(nil,nil,nil,true)")
        section[:messages] = []
        section[:messages] << "#{display_name} section failed and was skipped because: #{e}. Detail on error follows."
        section[:messages] << ["#{e.backtrace.join("\n")}"]
        @sections << section

      end

    end

    # read in template
    html_in_path = "#{File.dirname(__FILE__)}/resources/report.html.erb"
    if File.exist?(html_in_path)
      html_in_path = html_in_path
    else
      html_in_path = "#{File.dirname(__FILE__)}/report.html.erb"
    end
    html_in = ''
    File.open(html_in_path, 'r') do |file|
      html_in = file.read
    end

    # configure template with variable values
    renderer = ERB.new(html_in)
    html_out = renderer.result(binding)

    # write html file
    html_out_path = './report.html'
    File.open(html_out_path, 'w') do |file|
      file << html_out
      # make sure data is written to the disk one way or the other
      begin
        file.fsync
      rescue
        file.flush
      end
    end

    # closing the sql file
    sql_file.close

    # reporting final condition
    runner.registerFinalCondition("Generated report with #{sections_made} sections to #{html_out_path}.")

    true
  end # end the run method
end # end the measure

# this allows the measure to be use by the application
ILTRMReportMidriseApt.new.registerWithApplication
