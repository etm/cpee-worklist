def sendmail(adr, ok)
  if(ok.upcase == "OK")
    status = "Ihr Schaden wird von der Polizze gedeckt und wird behoben."
  else
    status = "Ihr Schaden wird nicht von der Polizze gedeckt. Jetzt haben Sie den Salat."
  end
  message = <<MESSAGE_END
From: Automatic Answer <automator@sahann.at>
To: Client <#{adr}>
Subject: Ihre Schadensmeldung

#{status}

Mit freundlichen Gruessen,
Ihre Versicherung
MESSAGE_END

  Net::SMTP.start('smtp.world4you.com', 587, 'raph.cs.univie.ac.at', 'automator@sahann.at', 'AutoPassword1') do |smtp|
    smtp.send_message message, 'automator@sahann.at', adr
  end
end

