import avatar from '../assets/images/avatar.jpg';
import hero from '../assets/images/hero.jpg';
import type { SiteConfig } from '../types';

const siteConfig: SiteConfig = {
    website: 'https://Juansebas375.github.io',
    avatar: {
        src: avatar,
        alt: 'Juan Rodriguez'
    },
    title: 'Juan Rodriguez',
    subtitle: 'Systems Engineering Student',
    description: 'Personal portfolio of Juan Rodriguez, a Systems Engineering student interested in web development and technology.',
    image: {
        src: '/dante-preview.jpg',
        alt: 'Juan Rodriguez - Personal Portfolio'
    },
    headerNavLinks: [
        {
            text: 'Home',
            href: '/'
        },
        {
            text: 'Projects',
            href: '/projects'
        },
        {
            text: 'Blog',
            href: '/blog'
        },
        {
            text: 'Tags',
            href: '/tags'
        },
        {
            text: 'Evidence',
            href: '/evidencias'
        }
    ],
    footerNavLinks: [
        {
            text: 'About',
            href: '/about'
        },
        {
            text: 'Contact',
            href: '/contact'
        },
        {
            text: 'Terms',
            href: '/terms'
        }
    ],
    socialLinks: [
        {
            text: 'GitHub',
            href: 'https://github.com/Juansebas375'
        },
        {
            text: 'Instagram',
            href: 'https://instagram.com/'
        },
        {
            text: 'X/Twitter',
            href: 'https://twitter.com/'
        }
    ],
    hero: {
        title: 'Hi, Welcome to My Website!',
        text: "I'm **Juan Rodriguez**, a Systems Engineering student interested in web development, software, and technology.\n\nOn this website, you can learn more about me, explore my projects, and see some of the work I have done.\n\nFeel free to explore my projects and check out my coding journey. If you would like to get in touch, you can reach me at **jrodriguezd2006@gmail.com**.",
        image: {
            src: hero,
            alt: 'Juan Rodriguez working on a computer'
        },
        actions: [
            {
                text: 'Get in Touch',
                href: '/contact'
            }
        ]
    },
    subscribe: {
        enabled: true,
        title: 'Contact',
        text: 'Email: jrodriguezd2006@gmail.com\nPhone: 3053980220',
        form: {
            action: '#'
        }
    },
    postsPerPage: 8,
    projectsPerPage: 8
};

export default siteConfig;