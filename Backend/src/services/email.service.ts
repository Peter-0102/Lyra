import nodemailer from 'nodemailer';
import { config } from '../config.js';

const transporter = nodemailer.createTransport({
  host: config.smtpHost,
  port: config.smtpPort,
  secure: config.smtpPort === 465,
  ...(config.smtpUser && config.smtpPass
    ? { auth: { user: config.smtpUser, pass: config.smtpPass } }
    : {}),
});

export async function sendPasswordResetEmail(to: string, code: string): Promise<void> {
  await transporter.sendMail({
    from: config.smtpFrom,
    to,
    subject: 'Mispoti - Password Reset Code',
    text: `Your password reset code is: ${code}\n\nThis code expires in 15 minutes.\n\nIf you did not request this, please ignore this email.`,
    html: `
      <h2>Mispoti - Password Reset</h2>
      <p>Your password reset code is:</p>
      <h1 style="font-size: 32px; letter-spacing: 8px; text-align: center; background: #f0f0f0; padding: 16px; border-radius: 8px;">${code}</h1>
      <p>This code expires in 15 minutes.</p>
      <p>If you did not request this, please ignore this email.</p>
    `,
  });
}
