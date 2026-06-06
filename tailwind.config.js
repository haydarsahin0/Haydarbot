/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        royal: {
          50: '#faf6ef',
          100: '#f3e9d2',
          200: '#e6cf9c',
          300: '#d8b163',
          400: '#cf9b3f',
          500: '#b67f2d',
          600: '#946224',
          700: '#714a20',
          800: '#5d3d21',
          900: '#4f351f',
        },
      },
      fontFamily: {
        display: ['"Cinzel"', 'Georgia', 'serif'],
      },
      boxShadow: {
        throne: '0 0 60px -10px rgba(250, 204, 21, 0.45)',
      },
      keyframes: {
        'pulse-glow': {
          '0%, 100%': { boxShadow: '0 0 40px -10px rgba(250,204,21,0.4)' },
          '50%': { boxShadow: '0 0 80px -5px rgba(250,204,21,0.7)' },
        },
        'flash': {
          '0%': { transform: 'scale(1)' },
          '40%': { transform: 'scale(1.06)' },
          '100%': { transform: 'scale(1)' },
        },
      },
      animation: {
        'pulse-glow': 'pulse-glow 2.5s ease-in-out infinite',
        'flash': 'flash 0.4s ease-out',
      },
    },
  },
  plugins: [],
};
