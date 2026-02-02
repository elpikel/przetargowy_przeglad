defmodule PrzetargowyPrzegladWeb.SiteComponents do
  @moduledoc """
  Site-wide UI components like headers, footers, and navigation.
  """
  use Phoenix.Component

  @doc """
  Renders the site page header with logo, navigation, and user controls.

  ## Attributes

    * `current_user` - The current user struct or nil
    * `position` - Header position: "fixed" or "sticky" (default: "sticky")

  ## Slots

    * `nav` - Optional navigation links
    * `cta` - Optional CTA buttons (overrides default login/register buttons)

  ## Examples

      <.page_header current_user={@current_user}>
        <:nav>
          <a href="/tenders">Szukaj przetargów</a>
          <a href="#cennik">Cennik</a>
        </:nav>
      </.page_header>

  """
  attr :current_user, :map, default: nil
  attr :position, :string, default: "sticky", values: ["fixed", "sticky"]
  attr :hide_default_cta, :boolean, default: false
  attr :hide_hamburger, :boolean, default: false

  slot :nav
  slot :cta

  def page_header(assigns) do
    ~H"""
    <header class={"site-header site-header--#{@position}"}>
      <div class="header-inner">
        <a href="/" class="logo">
          <div class="logo-icon">
            <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path
                d="M6 3C5.44772 3 5 3.44772 5 4V20C5 20.5523 5.44772 21 6 21H15C15.5523 21 16 20.5523 16 20V8L11 3H6Z"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
              <path
                d="M11 3V7C11 7.55228 11.4477 8 12 8H16"
                stroke="currentColor"
                stroke-width="1.5"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
              <path d="M7.5 12H12.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" />
              <path d="M7.5 15H10.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" />
              <circle cx="16.5" cy="14.5" r="4" fill="none" stroke="currentColor" stroke-width="1.5" />
              <path d="M19.5 17.5L22 20" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
            </svg>
          </div>
          <span class="logo-text">Przetargowy<span>Przegląd</span></span>
        </a>

        <%= if @nav != [] do %>
          <nav class="desktop-nav">
            {render_slot(@nav)}
          </nav>
        <% end %>

        <div class="header-cta">
          <%= if @hide_default_cta do %>
            {render_slot(@cta)}
          <% else %>
            <%= if @current_user do %>
              <span class="user-email">{@current_user.email}</span>
              <a href="/dashboard" class="btn btn-primary">Ustawienia</a>
              <a href="/logout" class="btn btn-outline">Wyloguj</a>
            <% else %>
              <a href="/login" class="btn btn-outline">Zaloguj się</a>
              <a href="/register" class="btn btn-primary">Rozpocznij za darmo</a>
            <% end %>
          <% end %>
        </div>

        <%= unless @hide_hamburger do %>
          <button class="hamburger" id="hamburger" aria-label="Menu">
            <span></span>
            <span></span>
            <span></span>
          </button>
        <% end %>
      </div>
    </header>

    <%= unless @hide_hamburger do %>
      <div class="mobile-menu" id="mobile-menu">
        <%= if @current_user do %>
          <div class="mobile-menu-user">
            <span class="mobile-menu-user-email">{@current_user.email}</span>
          </div>
          <a href="/dashboard" class="btn btn-primary">Ustawienia</a>
          <a href="/logout" class="mobile-link">Wyloguj się</a>
        <% else %>
          <a href="/login" class="btn btn-outline">Zaloguj się</a>
          <a href="/register" class="btn btn-primary">Rozpocznij za darmo</a>
        <% end %>
        <%= if @nav != [] do %>
          <div class="mobile-nav">
            {render_slot(@nav)}
          </div>
        <% end %>
      </div>
    <% end %>
    """
  end

  @doc """
  Renders the CSS styles for the page header component.
  Include this in the <head> section of pages using the header.
  """
  def page_header_styles(assigns) do
    ~H"""
    <style>
      /* Header Base Styles */
      .site-header {
        background: rgba(254, 252, 248, 0.92);
        backdrop-filter: blur(12px);
        border-bottom: 1px solid rgba(10, 22, 40, 0.06);
        z-index: 100;
        transition: all 0.3s ease;
      }
      .site-header--fixed {
        position: fixed;
        top: 0;
        left: 0;
        right: 0;
      }
      .site-header--sticky {
        position: sticky;
        top: 0;
      }
      .header-inner {
        display: flex;
        align-items: center;
        padding: 16px 24px;
        max-width: 1200px;
        margin: 0 auto;
        gap: 24px;
      }
      .logo {
        display: flex;
        align-items: center;
        gap: 12px;
        text-decoration: none;
        flex-shrink: 0;
      }
      .logo-icon {
        width: 44px;
        height: 44px;
        background: var(--cream-50);
        border: 2px solid var(--navy-600);
        border-radius: 10px;
        display: flex;
        align-items: center;
        justify-content: center;
        box-shadow: 0 4px 12px rgba(10, 22, 40, 0.1);
        position: relative;
        overflow: hidden;
      }
      .logo-icon svg {
        width: 26px;
        height: 26px;
        color: var(--navy-700);
      }
      .logo-text {
        font-family: 'Playfair Display', serif;
        font-weight: 700;
        font-size: 1.35rem;
        color: var(--navy-800);
        letter-spacing: -0.02em;
      }
      .logo-text span {
        color: var(--gold-500);
      }

      /* Desktop Navigation */
      .desktop-nav {
        display: flex;
        align-items: center;
        gap: clamp(16px, 3vw, 32px);
        margin: 0 auto;
      }
      .desktop-nav a {
        text-decoration: none;
        color: var(--text-secondary);
        font-weight: 500;
        font-size: 0.95rem;
        transition: color 0.2s ease;
        position: relative;
      }
      .desktop-nav a::after {
        content: '';
        position: absolute;
        bottom: -4px;
        left: 0;
        width: 0;
        height: 2px;
        background: var(--navy-600);
        transition: width 0.2s ease;
      }
      .desktop-nav a:hover {
        color: var(--navy-800);
      }
      .desktop-nav a:hover::after {
        width: 100%;
      }

      /* Header CTA */
      .header-cta {
        display: flex;
        align-items: center;
        gap: 12px;
        flex-shrink: 0;
      }
      .header-cta .btn {
        padding: 12px 24px;
        font-size: 0.95rem;
        min-height: 44px;
        box-sizing: border-box;
      }
      .user-email {
        font-size: 0.85rem;
        color: var(--text-secondary);
        max-width: 160px;
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
      }

      /* Mobile hamburger button */
      .hamburger {
        display: none;
        flex-direction: column;
        justify-content: center;
        gap: 5px;
        width: 32px;
        height: 32px;
        cursor: pointer;
        z-index: 110;
        background: transparent;
        border: none;
        padding: 0;
      }
      .hamburger span {
        display: block;
        width: 24px;
        height: 2px;
        background: var(--navy-700);
        transition: all 0.3s ease;
      }
      .hamburger.active span:nth-child(1) {
        transform: rotate(45deg) translate(5px, 5px);
      }
      .hamburger.active span:nth-child(2) {
        opacity: 0;
      }
      .hamburger.active span:nth-child(3) {
        transform: rotate(-45deg) translate(5px, -5px);
      }

      /* Mobile menu */
      .mobile-menu {
        display: none;
        position: fixed;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        background: var(--cream-50);
        z-index: 99;
        padding: 100px 24px 40px;
        flex-direction: column;
        align-items: center;
        gap: 24px;
      }
      .mobile-menu.active {
        display: flex;
      }
      .mobile-menu-user {
        padding: 16px;
        background: var(--cream-100);
        border-radius: 12px;
        margin-bottom: 8px;
        width: 100%;
        max-width: 280px;
        text-align: center;
      }
      .mobile-menu-user-email {
        font-size: 0.9rem;
        color: var(--navy-800);
        font-weight: 500;
        word-break: break-all;
      }
      .mobile-menu .btn {
        width: 100%;
        max-width: 280px;
        justify-content: center;
      }
      .mobile-link, .mobile-nav a {
        text-decoration: none;
        color: var(--navy-800);
        font-weight: 600;
        font-size: 1.25rem;
        padding: 12px 0;
      }
      .mobile-nav {
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 8px;
        margin-top: 16px;
      }

      /* Responsive */
      @media (max-width: 1100px) {
        .header-cta .btn {
          padding: 10px 16px;
          font-size: 0.9rem;
          min-height: 40px;
        }
      }
      @media (max-width: 1050px) {
        .header-inner {
          justify-content: space-between;
        }
        .desktop-nav {
          display: none;
        }
        .header-cta {
          display: none;
        }
        .hamburger {
          display: flex;
        }
      }
      @media (max-width: 640px) {
        .header-inner {
          padding: 12px 16px;
        }
        .logo-text {
          font-size: 1.1rem;
        }
      }
    </style>
    """
  end

  @doc """
  Renders the JavaScript for the mobile menu toggle.
  Include this at the bottom of the page body.
  """
  def page_header_script(assigns) do
    ~H"""
    <script>
      (function() {
        const hamburger = document.getElementById('hamburger');
        const mobileMenu = document.getElementById('mobile-menu');
        const mobileLinks = mobileMenu ? mobileMenu.querySelectorAll('a') : [];

        function closeMenu() {
          if (hamburger) hamburger.classList.remove('active');
          if (mobileMenu) mobileMenu.classList.remove('active');
          document.body.style.overflow = '';
        }

        if (hamburger) {
          hamburger.addEventListener('click', () => {
            hamburger.classList.toggle('active');
            if (mobileMenu) mobileMenu.classList.toggle('active');
            document.body.style.overflow = mobileMenu && mobileMenu.classList.contains('active') ? 'hidden' : '';
          });
        }

        mobileLinks.forEach(link => {
          link.addEventListener('click', closeMenu);
        });

        window.addEventListener('resize', () => {
          if (window.innerWidth > 1050) {
            closeMenu();
          }
        });
      })();
    </script>
    """
  end

  @doc """
  Renders the site footer.
  """
  attr :class, :string, default: nil

  def page_footer(assigns) do
    ~H"""
    <footer id="kontakt" class={@class}>
      <div class="container">
        <div class="footer-content">
          <div class="footer-brand">
            <a href="/" class="logo">
              <div class="logo-icon">
                <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path
                    d="M6 3C5.44772 3 5 3.44772 5 4V20C5 20.5523 5.44772 21 6 21H15C15.5523 21 16 20.5523 16 20V8L11 3H6Z"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="1.5"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  />
                  <path
                    d="M11 3V7C11 7.55228 11.4477 8 12 8H16"
                    stroke="currentColor"
                    stroke-width="1.5"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  />
                  <path d="M7.5 12H12.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" />
                  <path d="M7.5 15H10.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" />
                  <circle cx="16.5" cy="14.5" r="4" fill="none" stroke="currentColor" stroke-width="1.5" />
                  <path d="M19.5 17.5L22 20" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
                </svg>
              </div>
              <span class="logo-text">Przetargowy<span>Przegląd</span></span>
            </a>
            <p>
              Automatyczny monitoring zamówień publicznych. Oszczędzaj czas i nie przegap żadnej okazji biznesowej.
            </p>
          </div>
          <div class="footer-links">
            <h4>Produkt</h4>
            <ul>
              <li><a href="/tenders">Szukaj przetargów</a></li>
              <li><a href="/#jak-dziala">Jak to działa</a></li>
              <li><a href="/#cennik">Cennik</a></li>
            </ul>
          </div>
          <div class="footer-links">
            <h4>Kontakt</h4>
            <ul>
              <li>
                <a href="mailto:kontakt@przetargowyprzeglad.pl">kontakt@przetargowyprzeglad.pl</a>
              </li>
            </ul>
          </div>
        </div>
        <div class="footer-bottom">
          <p>© 2026 Przetargowy Przegląd. Wszelkie prawa zastrzeżone.</p>
          <div class="footer-legal">
            <a href="/rules">Regulamin</a>
            <a href="/privacy-policy">Polityka prywatności</a>
          </div>
        </div>
      </div>
    </footer>
    """
  end

  @doc """
  Renders the CSS styles for the page footer.
  """
  def page_footer_styles(assigns) do
    ~H"""
    <style>
      footer {
        background: var(--cream-100);
        padding: 60px 0 30px;
        border-top: 1px solid var(--cream-300);
      }
      .footer-content {
        display: grid;
        grid-template-columns: 1.5fr 1fr 1fr;
        gap: 60px;
        margin-bottom: 48px;
      }
      .footer-brand .logo {
        margin-bottom: 20px;
      }
      .footer-brand p {
        color: var(--text-secondary);
        font-size: 0.95rem;
        max-width: 320px;
      }
      .footer-links h4 {
        font-size: 0.9rem;
        font-weight: 600;
        color: var(--navy-800);
        text-transform: uppercase;
        letter-spacing: 0.08em;
        margin-bottom: 20px;
      }
      .footer-links ul {
        list-style: none;
      }
      .footer-links li {
        margin-bottom: 12px;
      }
      .footer-links a {
        color: var(--text-secondary);
        text-decoration: none;
        font-size: 0.95rem;
        transition: color 0.2s ease;
      }
      .footer-links a:hover {
        color: var(--navy-700);
      }
      .footer-bottom {
        padding-top: 24px;
        border-top: 1px solid var(--cream-300);
        display: flex;
        justify-content: space-between;
        align-items: center;
      }
      .footer-bottom p {
        color: var(--text-secondary);
        font-size: 0.85rem;
      }
      .footer-legal {
        display: flex;
        gap: 24px;
      }
      .footer-legal a {
        color: var(--text-secondary);
        text-decoration: none;
        font-size: 0.85rem;
        transition: color 0.2s ease;
      }
      .footer-legal a:hover {
        color: var(--navy-700);
      }
      @media (max-width: 968px) {
        .footer-content {
          grid-template-columns: 1fr;
          gap: 40px;
        }
      }
      @media (max-width: 640px) {
        .footer-bottom {
          flex-direction: column;
          gap: 16px;
          text-align: center;
        }
      }
    </style>
    """
  end
end
