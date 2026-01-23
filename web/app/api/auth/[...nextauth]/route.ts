
import NextAuth from "next-auth";
import CredentialsProvider from "next-auth/providers/credentials";

const handler = NextAuth({
    providers: [
        CredentialsProvider({
            name: "Credentials",
            credentials: {
                username: { label: "Username", type: "text", placeholder: "guest" },
                password: { label: "Password", type: "password" }
            },
            async authorize(credentials, req) {
                // Mock login for demonstration
                // Accepting any username/password for now
                if (credentials?.username) {
                    return { id: "1", name: credentials.username, email: `${credentials.username}@example.com` };
                }
                return null;
            }
        })
    ],
    pages: {
        signIn: '/login',
    },
    callbacks: {
        async session({ session, token }) {
            return session;
        },
    },
});

export { handler as GET, handler as POST };
