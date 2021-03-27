require 'date'
require 'nokogiri'

require_relative '../sentry_helper'
require_relative './base_clinic'

module MyChart
  class Page
    def initialize(storage, logger)
      @storage = storage
      @logger = logger
    end

    def credentials
      response = RestClient.get(token_url)
      cookies = response.cookies
      doc = Nokogiri::HTML(response)
      token = doc.search('input[name=__RequestVerificationToken]')[0]['value']
      {
        cookies: cookies,
        '__RequestVerificationToken' => token,
      }
    end

    def appointments_json(start)
      payload = api_payload
      payload['start'] = start.strftime('%Y-%m-%d')
      res = RestClient.post(
        "#{scheduling_api_url}?noCache=#{Time.now.to_i}",
        payload,
        credentials
      )
      JSON.parse(res.body)
    end

    def clinics
      slots = {}

      date = Date.today
      4.times do
        json = appointments_json(date)
        json['ByDateThenProviderCollated'].each do |date, date_info|
          date_info['ProvidersAndHours'].each do |_provider, provider_info|
            provider_info['DepartmentAndSlots'].each do |department, department_info|
              department_info['HoursAndSlots'].each do |_hour, hour_info|
                slots[date] ||= { department: json['AllDepartments'][department], slots: 0 }
                slots[date][:slots] += hour_info['Slots'].length
              end
            end
          end
        end
        date += 7
      end

      slots.map do |date, info|
        @logger.info "[MyChart] Site #{info[:department]['Name']} on #{date}: found #{info[:slots]} appointments"
        Clinic.new(info[:department], date, info[:slots], sign_up_page, @logger, @storage)
      end
    end
  end

  class UMassMemorial < Page
    def name
      'UMass Memorial'
    end

    def token_url
      'https://mychartonline.umassmemorial.org/mychart/openscheduling?specialty=15&hidespecialtysection=1'
    end

    def scheduling_api_url
      'https://mychartonline.umassmemorial.org/MyChart/OpenScheduling/OpenScheduling/GetScheduleDays'
    end

    def api_payload
      {
        'view' => 'grouped',
        'specList' => '15',
        'vtList' => '5060',
        'start' => '',
        'filters' => {
          'Providers' => {},
          'Departments' => {},
          'DaysOfWeek' => {},
          'TimesOfDay': 'both',
        },
      }
    end

    def sign_up_page
      'https://mychartonline.umassmemorial.org/mychart/openscheduling?specialty=15&hidespecialtysection=1'
    end
  end

  class SBCHC < Page
    def name
      'SBCHC'
    end

    def token_url
      'https://mychartos.ochin.org/mychart/SignupAndSchedule/EmbeddedSchedule?id=1900119&dept=150001007&vt=1089&payor=-1,-2,-3,4653,1624,4660,4655,1292,4881,5543,5979,2209,5257,1026,1001,2998,3360,3502,4896,2731'
    end

    def scheduling_api_url
      'https://mychartos.ochin.org/mychart/OpenScheduling/OpenScheduling/GetOpeningsForProvider'
    end

    def api_payload
      {
        'id' => '1900119',
        'vt' => '1089',
        'dept' => '150001007',
        'view' => 'grouped',
        'start' => '',
        'filters' => {
          'Providers' => {},
          'Departments' => {},
          'DaysOfWeek' => {},
          'TimesOfDay': 'both',
        },
      }
    end

    def sign_up_page
      'https://forms.office.com/Pages/ResponsePage.aspx?id=J8HP3h4Z8U-yP8ih3jOCukT-1W6NpnVIp4kp5MOEapVUOTNIUVZLODVSMlNSSVc2RlVMQ1o1RjNFUy4u'
    end
  end

  class BMC < Page
    def name
      'BMC'
    end

    def token_url
      'https://mychartscheduling.bmc.org/mychartscheduling/SignupAndSchedule/EmbeddedSchedule'
    end

    def scheduling_api_url
      'https://mychartscheduling.bmc.org/MyChartscheduling/OpenScheduling/OpenScheduling/GetOpeningsForProvider'
    end

    def api_payload
      {
        'id' => '10033319,10033364,10033367,10033370,10033706,10033373',
        'vt' => '2008',
        'dept' => '10098245,10098242,10098243,10098244,10108801,10098241',
        'view' => 'grouped',
        'start' => '',
        'filters' => {
          'Providers' => {},
          'Departments' => {},
          'DaysOfWeek' => {},
          'TimesOfDay': 'both',
        },
      }
    end

    def sign_up_page
      'https://mychartscheduling.bmc.org/MyChartscheduling/covid19#/'
    end
  end

  class MassGeneralBrigham < Page
    def clinic_identifier
      raise NotImplementedError
    end

    def credentials
      token_response = RestClient.get('https://covidvaccine.massgeneralbrigham.org/')
      token_doc = Nokogiri::HTML(token_response.body)
      token = token_doc.search('input[name=__RequestVerificationToken]')[0]['value']

      session_response = RestClient.post(
        'https://covidvaccine.massgeneralbrigham.org/Home/CreateSession',
        {},
        cookies: token_response.cookies,
        RequestVerificationToken: token
      )

      redirect_response = RestClient.post(
        'https://covidvaccine.massgeneralbrigham.org/Home/RedirectUrl',
        {
          Institution: clinic_identifier,
          tokenStr: session_response.body,
        },
        cookies: token_response.cookies,
        RequestVerificationToken: token
      )

      scheduling_page = RestClient.get(redirect_response)
      scheduling_doc = Nokogiri(scheduling_page.body)
      scheduling_token = scheduling_doc.search('input[name=__RequestVerificationToken]')[0]['value']
      {
        cookies: scheduling_page.cookies,
        '__RequestVerificationToken' => scheduling_token,
      }
    end
  end

  class MarthasVinyard < MassGeneralBrigham
    def name
      "Martha's Vineyard Hospital"
    end

    def clinic_identifier
      'MVH'
    end

    def scheduling_api_url
      'https://patientgateway.massgeneralbrigham.org/MyChart-PRD/OpenScheduling/OpenScheduling/GetOpeningsForProvider'
    end

    def api_payload
      {
        'vt' => '555097',
        'dept' => '10110010104',
        'view' => 'grouped',
        'start' => '',
        'filters' => {
          'Providers' => {},
          'Departments' => {},
          'DaysOfWeek' => {},
          'TimesOfDay' => 'both',
        }.to_json,
      }
    end

    def sign_up_page
      'https://covidvaccine.massgeneralbrigham.org/'
    end
  end

  class Nantucket < MassGeneralBrigham
    def name
      'Nantucket VFW'
    end

    def clinic_identifier
      'NCH'
    end

    def scheduling_api_url
      'https://patientgateway.massgeneralbrigham.org/MyChart-PRD/OpenScheduling/OpenScheduling/GetOpeningsForProvider'
    end

    def api_payload
      {
        'vt' => '555097',
        'dept' => '10120040001',
        'view' => 'grouped',
        'start' => '',
        'filters' => {
          'Providers' => {},
          'Departments' => {},
          'DaysOfWeek' => {},
          'TimesOfDay' => 'both',
        },
      }
    end

    def sign_up_page
      'https://covidvaccine.massgeneralbrigham.org/'
    end
  end

  ALL_PAGES = [
    UMassMemorial,
    BMC,
    SBCHC,
    MarthasVinyard,
    Nantucket,
  ].freeze

  def self.all_clinics(storage, logger)
    ALL_PAGES.flat_map do |page_class|
      sleep(2)
      SentryHelper.catch_errors(logger, 'MyChart') do
        page = page_class.new(storage, logger)
        logger.info "[MyChart] Checking site #{page.name}"
        page.clinics
      end
    end
  end

  class Clinic < BaseClinic
    attr_reader :date, :appointments, :link

    def initialize(department, date, appointments, link, logger, storage)
      super(storage)
      @department = department
      @date = date
      @appointments = appointments
      @link = link
      @logger = logger
    end

    def name
      @department['Name']
    end

    def address
      "#{@department['Address']['Street'].join(' ')}, #{city}, MA"
    end

    def city
      @department['Address']['City'].split.map(&:capitalize).join(' ')
    end

    def title
      "#{name} on #{@date}"
    end

    def sign_up_page
      link
    end

    def slack_blocks
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: "*#{title}*\n*Address:* #{address}\n*Available appointments:* #{render_slack_appointments}\n*Link:* #{link}",
        },
      }
    end

    def twitter_text
      txt = "#{appointments} appointments available at #{name}"
      txt += " in #{city}, MA" if city
      txt + " on #{date}. Check eligibility and sign up at #{sign_up_page}"
    end
  end
end
