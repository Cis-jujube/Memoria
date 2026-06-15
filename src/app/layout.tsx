import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Memoria - AI Friend Memory",
  description:
    "A private AI relationship memory command center for students and young adults.",
  appleWebApp: {
    capable: true,
    statusBarStyle: "black-translucent",
    title: "Memoria",
  },
  applicationName: "Memoria",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: "#10231f",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="h-full antialiased">
      <body className="min-h-full bg-[#f5f7f4] text-[#17231f]">
        {children}
      </body>
    </html>
  );
}
