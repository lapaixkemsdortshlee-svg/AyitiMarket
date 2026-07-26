// Konfigirasyon Tailwind pou konpile CSS estatik la (assets/tw.css).
// MENM valè ak ansyen blòk `tailwind.config` inline nan index.html -
// si w chanje yon koulè/font isit la, rebati: npm run build:css
module.exports = {
  content: ['./index.html'],
  theme: {
    extend: {
      colors: {
        "primary": "#00666f", "primary-container": "#00818c", "primary-fixed": "#8cf2ff",
        "primary-fixed-dim": "#5ad7e6", "on-primary-fixed": "#001f23",
        "surface": "#fcf9f4", "surface-container-lowest": "#ffffff",
        "surface-container-low": "#f6f3ee", "surface-container": "#f0ede8",
        "surface-container-high": "#ebe8e3", "surface-container-highest": "#e5e2dd",
        "on-surface": "#1c1c19", "on-surface-variant": "#3d4949", "outline-variant": "#bcc9c8",
        "secondary": "#98443e", "secondary-container": "#f99188",
        "tertiary": "#97422b", "tertiary-container": "#b65a41",
      },
      fontFamily: { headline: ["Plus Jakarta Sans"], body: ["Manrope"], label: ["Manrope"] },
      borderRadius: { DEFAULT: "0.5rem", lg: "1rem", xl: "1.5rem", full: "9999px" }
    }
  }
};
