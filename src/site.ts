// Everything about you, in one place. Name, contact details and social links
// are edited in the admin (Settings) and read from Supabase at build time;
// the rest of the text is here.
import { settings } from './lib/build-data';

export const site = {
  brand: 'Trutech Business',
  tagline: 'Where ideas turn into reality.',
  role: 'Technology entrepreneur & digital solutions practitioner',
  headline: 'Practical digital solutions for businesses, schools and people in Ghana.',
  intro:
    'I design, build and support digital products: responsive websites, management systems, online platforms and brand identities that make work easier and help organisations run better.',
  ...settings,

  about: {
    paragraphs: [
      'I am a technology entrepreneur and digital solutions practitioner working across web development, software solutions, graphic design, IT support and educational technology.',
      'Through Trutech Business I use technology and creativity to build practical solutions for businesses, schools and individuals: responsive websites, database-driven management systems, administrative dashboards, payment and API integrations, and platforms for online services. I am also building TRU DATA, a digital commerce platform for mobile data bundles.',
      'I also work in brand identity and promotional design, computer hardware and troubleshooting, and as an ICT teacher. Everything I build starts from a real need: what problem it solves, how people will use it, and how it will be run and maintained.',
    ],
    stats: [
      { value: '5', label: 'Service areas' },
      { value: '4', label: 'Systems & platforms in progress' },
      { value: '2', label: 'Brands built: Trutech & TRU DATA' },
    ],
    roles: [
      { title: 'Web application developer', text: 'Dashboards, user accounts, records, databases and business workflows.' },
      { title: 'Technology entrepreneur', text: 'Digital services and online business models through Trutech Business and TRU DATA.' },
      { title: 'Graphic designer', text: 'Branding, marketing graphics and image assets for businesses and institutions.' },
      { title: 'IT support & problem-solver', text: 'Software errors, device compatibility, computer upgrades and installation problems.' },
      { title: 'Educational technology practitioner', text: 'Connecting computing to classroom teaching, school administration and learning materials.' },
    ],
    toolkit: [
      { area: 'Web development', tools: ['Visual Studio Code', 'HTML', 'CSS', 'JavaScript', 'Framer', 'GitHub Pages'] },
      { area: 'Backend & data', tools: ['Supabase', 'PostgreSQL', 'Authentication', 'Row Level Security'] },
      { area: 'Payments & integrations', tools: ['Paystack', 'Refer2Bundle API', 'AdSense', 'AdMob'] },
      { area: 'Design', tools: ['Affinity by Canva', 'Framer'] },
      { area: 'Mobile & hardware', tools: ['Android APK workflows', 'Android SDK', 'Windows 11 diagnostics', 'RAM & SSD upgrades'] },
      { area: 'Vector & production', tools: ['Inkscape', 'Ink/Stitch', 'SVG'] },
    ],
  },

  // Icons: brand, web, code, growth, support, design, chat
  services: [
    {
      icon: 'web',
      title: 'Websites & web apps',
      text: 'Responsive, lightweight websites and web applications that work well on phones and computers, with accounts, forms, dashboards and navigation.',
      points: ['Business & personal websites', 'Login, registration & dashboards', 'GitHub Pages hosting & custom domains'],
    },
    {
      icon: 'code',
      title: 'Management systems',
      text: 'Database-driven systems that run real operations: records, roles and permissions, reports, attendance, fees and admin panels.',
      points: ['School management', 'Dues & group finance', 'Role-based access with Supabase'],
    },
    {
      icon: 'growth',
      title: 'Digital commerce & payments',
      text: 'Online storefronts and services with secure accounts, Paystack payments, API integrations, order tracking and agent systems.',
      points: ['Paystack & mobile money', 'API integrations', 'Orders, agents & withdrawals'],
    },
    {
      icon: 'brand',
      title: 'Branding & graphic design',
      text: 'Logos, brand identities, flyers, banners and event graphics with consistent colour and sharp, print-ready output.',
      points: ['Logos & brand identity', 'Flyers, banners & adverts', 'Photo editing & retouching'],
    },
    {
      icon: 'support',
      title: 'IT support & ICT training',
      text: 'Hands-on troubleshooting, hardware upgrades and ICT lessons that help people and schools use technology with confidence.',
      points: ['Windows & device troubleshooting', 'RAM & SSD upgrades', 'ICT lessons & training'],
    },
  ],

  process: [
    { title: 'Understand the need', text: 'What problem should this solve, and for whom? We agree on the goal before anything is built.' },
    { title: 'Design the experience', text: 'Interfaces, brand and flows, shaped around how your users will actually use it.' },
    { title: 'Build & connect', text: 'Accounts, data, payments and integrations: implemented, tested and secured.' },
    { title: 'Launch & support', text: 'Deployment, training and maintenance, so it keeps working after go-live.' },
  ],

  /** Shown only once you add real ones. */
  testimonials: [] as { quote: string; name: string; role: string }[],
};

export const whatsappLink = (text = 'Hello! I found you through the Trutech Business website.') =>
  site.whatsapp ? `https://wa.me/${site.whatsapp}?text=${encodeURIComponent(text)}` : '';
