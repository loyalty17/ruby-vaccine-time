class MockClinic
  attr_reader :title, :appointments, :new_appointments, :link

  def initialize(title: 'Mock clinic on 01/01/2021',
                 appointments: 0,
                 new_appointments: 0,
                 link: 'clinicsite.com',
                 has_not_posted_recently: true)
    @title = title
    @appointments = appointments
    @new_appointments = new_appointments
    @link = link
    @has_not_posted_recently = has_not_posted_recently
  end

  def twitter_text
    "#{appointments} appointments available at #{title}. Check eligibility and sign up at #{link}"
  end

  def storage_key
    title
  end

  def slack_blocks
    {
      type: 'section',
      text: {
        type: 'mrkdwn',
        text: "*#{title}*\n*Available appointments:* #{appointments}\n*Link:* #{link}",
      },
    }
  end

  def has_not_posted_recently?
    @has_not_posted_recently
  end

  def save_tweet_time
    nil
  end
end
