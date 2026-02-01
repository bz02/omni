import { NextAuthOptions } from "next-auth";
import CredentialsProvider from "next-auth/providers/credentials";
import { PrismaAdapter } from "@auth/prisma-adapter";
import { prisma } from "@/lib/prisma";
import bcrypt from "bcrypt";

export const authOptions: NextAuthOptions = {
    adapter: PrismaAdapter(prisma) as any, // Type assertion for compatibility if needed
    session: {
        strategy: "jwt",
    },
    providers: [
        CredentialsProvider({
            name: "Credentials",
            credentials: {
                username: { label: "Username", type: "text", placeholder: "guest" },
                password: { label: "Password", type: "password" }
            },
            async authorize(credentials, req) {
                if (!credentials?.username || !credentials?.password) return null;

                // For guest access without registration, we can still allow specific bypass
                if (credentials.username === "Guest") {
                    return { id: "guest", name: "Guest", email: "guest@example.com" };
                }

                const user = await prisma.user.findUnique({
                    where: { email: `${credentials.username}@example.com` } // Simple mapping for username->email
                });

                if (user && user.password) {
                    const isValid = await bcrypt.compare(credentials.password, user.password);
                    if (isValid) return user;
                } else {
                    // Auto-register for demo simplicity
                    const hashedPassword = await bcrypt.hash(credentials.password, 10);
                    const newUser = await prisma.user.create({
                        data: {
                            name: credentials.username,
                            email: `${credentials.username}@example.com`,
                            password: hashedPassword
                        }
                    });
                    return newUser;
                }
                return null;
            }
        })
    ],
    pages: {
        signIn: '/login',
    },
    callbacks: {
        async session({ session, token }: any) {
            if (session.user && token.sub) {
                session.user.id = token.sub;
            }
            return session;
        },
    },
};
