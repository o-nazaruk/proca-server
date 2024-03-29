const crypto = require('crypto');
const axios = require('axios').default;
const dotenv = require('dotenv');
dotenv.config();

import { Signature, Verification } from "./data";

const makeHeaders = () => {
  const key = process.env['TRUST_KEY'];
  if (!key) throw Error("TRUST_KEY not set");
  const stamp = Math.floor(Math.floor(Date.now() / 1000) / 30).toString();
  const token = crypto.createHmac("sha256", key).update(stamp).digest().toString('hex');

  return {
    headers: {
      'Authorization': `Token token="proca-test:${token}"`,
      'Content-Type': 'application/json'
    }
  }
}

export const rabbit = () => {
  return {
    user: process.env.RABBIT_USER,
    pass: process.env.RABBIT_PASSWORD,
    queueDeliver: process.env.RABBIT_QUEUE
  }
}

export const postAction = async (body: Signature) => {
  try {
    const { data, status } = await axios.post(
      process.env.POST_URL,
      body,
      makeHeaders()
    );
    console.log('Post status: ', status, data);
    return data;
    } catch (error: any) {
    if (axios.isAxiosError(error)) {
      console.log('post error: ', error.code, error.config.data, error.message, error.response.status, error.response.statusText);
      return error.message;
    } else {
      console.log('post unexpected error: ', error);
      return 'An unexpected error occurred';
    }
  }
}

export const verification = async (verificationToken: string, body: Verification) => {
  const url = process.env.VERIFICATION_URL + verificationToken + '/verify';
  try {
    const { data, status } = await axios.post(
      url,
      body,
      makeHeaders()
    );
    console.log('Verification status: ', status, data);
    return data;
    } catch (error: any) {
    if (axios.isAxiosError(error)) {
      console.log('verification error: ', error.message, error);
      return error.message;
    } else {
      console.log('verification unexpected error: ', error);
      return 'An unexpected error occurred';
    }
  }
}

export const lookup = async (email: string) => {
  const url = process.env.LOOKUP_URL + email;
  try {
    const { data, status } = await axios.get(url, makeHeaders());
    return {success: true, status:status, data:data};
    } catch (error: any) {
      return {success:false, status:error.response?.status, data: error.response};
  }
}
