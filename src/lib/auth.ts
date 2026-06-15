import { PrismaAdapter } from "@auth/prisma-adapter";
import type { NextAuthOptions } from "next-auth";
import CredentialsProvider from "next-auth/providers/credentials";
import GoogleProvider from "next-auth/providers/google";

import { prisma } from "@/lib/db";
import { runtimeFlags } from "@/lib/env";
import { normalizeEmail, verifyPassword } from "@/lib/password";

const providers: NextAuthOptions["providers"] = [
  ...(runtimeFlags.hasPasswordAuth()
    ? [
        CredentialsProvider({
          id: "credentials",
          name: "Email and password",
          credentials: {
            email: { label: "Email", type: "email" },
            password: { label: "Password", type: "password" },
          },
          async authorize(credentials) {
            const email = normalizeEmail(String(credentials?.email || ""));
            const password = String(credentials?.password || "");

            if (!email || !password) {
              return null;
            }

            const user = await prisma.user.findUnique({ where: { email } });

            if (!user || !verifyPassword(password, user.passwordHash)) {
              return null;
            }

            return {
              id: user.id,
              email: user.email,
              image: user.image,
              name: user.name,
            };
          },
        }),
      ]
    : []),
  ...(runtimeFlags.hasGoogleAuth()
    ? [
        GoogleProvider({
          clientId: process.env.GOOGLE_CLIENT_ID!,
          clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
        }),
      ]
    : []),
];

export const authOptions: NextAuthOptions = {
  adapter: PrismaAdapter(prisma),
  providers,
  secret: process.env.NEXTAUTH_SECRET || process.env.AUTH_SECRET,
  session: {
    strategy: "jwt",
  },
  pages: {
    signIn: "/",
  },
  callbacks: {
    jwt({ token, user }) {
      if (user?.id) {
        token.id = user.id;
      }

      return token;
    },
    session({ session, token }) {
      if (session.user) {
        session.user.id = typeof token.id === "string" ? token.id : "";
      }
      return session;
    },
  },
};
