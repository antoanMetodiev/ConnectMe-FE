// Issues a short-lived Stream Video user token for the caller.
//
// The Stream API secret must never reach the Flutter client — this function
// is the only place it's used. It verifies the caller's Supabase session,
// then signs a JWT Stream accepts as proof of identity for that user_id.
// Manual JWT construction (no Stream server SDK for Deno) per Stream's
// documented format: header {alg: HS256, typ: JWT}, payload
// {user_id, iat, exp}, HMAC-SHA256 signature, base64url without padding.

import { createClient } from "jsr:@supabase/supabase-js@2";

const STREAM_API_SECRET = Deno.env.get("STREAM_API_SECRET")!;
const TOKEN_VALIDITY_SECONDS = 24 * 60 * 60;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function base64url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function signStreamUserToken(userId: string): Promise<string> {
  const encoder = new TextEncoder();
  const now = Math.floor(Date.now() / 1000);

  const header = base64url(encoder.encode(JSON.stringify({ alg: "HS256", typ: "JWT" })));
  const payload = base64url(
    encoder.encode(
      JSON.stringify({
        user_id: userId,
        iat: now,
        exp: now + TOKEN_VALIDITY_SECONDS,
      }),
    ),
  );
  const unsigned = `${header}.${payload}`;

  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(STREAM_API_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signatureBuffer = await crypto.subtle.sign("HMAC", key, encoder.encode(unsigned));
  const signature = base64url(new Uint8Array(signatureBuffer));

  return `${unsigned}.${signature}`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const {
      data: { user },
      error,
    } = await supabase.auth.getUser();
    if (error || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const token = await signStreamUserToken(user.id);

    return new Response(JSON.stringify({ token, userId: user.id }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
