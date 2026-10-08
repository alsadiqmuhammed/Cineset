// Transactional email over SMTP (any provider: Resend, Postmark, SendGrid, Mailgun, SES, Gmail...).
// Without SMTP_HOST, emails are not sent and the app keeps working (invite links are still shown in the UI).
function openMailer(){
  const e=process.env;
  if(!e.SMTP_HOST)return {enabled:false,async send(){return false;}};
  const nodemailer=require('nodemailer');
  const port=Number(e.SMTP_PORT||587);
  const transport=nodemailer.createTransport({
    host:e.SMTP_HOST,
    port,
    secure:e.SMTP_SECURE?e.SMTP_SECURE==='true':port===465,
    auth:e.SMTP_USER?{user:e.SMTP_USER,pass:e.SMTP_PASSWORD||''}:undefined,
    // Fail fast so a slow mail server doesn't hold up the request that triggered the email.
    connectionTimeout:10000,greetingTimeout:10000,socketTimeout:20000,
  });
  const from=e.SMTP_FROM||e.SMTP_USER;
  return {
    enabled:true,
    async send({to,subject,text}){
      try{await transport.sendMail({from,to,subject,text});return true;}
      catch(err){console.error(`Email to ${to} failed:`,err.message);return false;}
    },
  };
}

module.exports={openMailer};
