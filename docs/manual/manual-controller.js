/**
 * ============================================================================
 * FSI COURIER MOBILE APP - USER MANUAL RENDERING CONTROLLER
 * ============================================================================
 * This script reads the uniform JSON data from window.MANUAL_DATA and
 * dynamically renders the HTML UI layout, theme states, search functionality,
 * and versioning history changelogs.
 */

document.addEventListener("DOMContentLoaded", () => {
  // Initialize App
  initHeaderLogos(window.MANUAL_DATA);
  renderSidebarMenu(window.MANUAL_DATA);
  renderManualContent(window.MANUAL_DATA);
  initVersionControl(window.MANUAL_DATA);
  initTheme();
  initScrollSpy();
});

// ==========================================
// 1. RENDER BRAND LOGOS FROM ASSETS
// ==========================================
function initHeaderLogos(data) {
  // Set logo in desktop sidebar
  const sidebarHeader = document.querySelector(".sidebar-header .brand");
  if (sidebarHeader) {
    sidebarHeader.innerHTML = `
      <img class="brand-logo" src="${data.logoPath}" alt="${data.brandName} Logo" style="width: 38px; height: 38px; object-fit: contain; border-radius: 8px;">
      <div>
        <div class="brand-name">${data.brandName}</div>
        <div class="brand-subtitle">User Manual</div>
      </div>
    `;
  }

  // Set logo in mobile header
  const mobileHeader = document.querySelector(".mobile-header .brand");
  if (mobileHeader) {
    mobileHeader.innerHTML = `
      <img class="brand-logo" src="${data.logoPath}" alt="${data.brandName} Logo" style="width: 34px; height: 34px; object-fit: contain; border-radius: 6px;">
      <div>
        <div class="brand-name">${data.brandName}</div>
        <div class="brand-subtitle">User Manual</div>
      </div>
    `;
  }
}

// ==========================================
// 2. RENDER SIDEBAR MENU
// ==========================================
function renderSidebarMenu(data) {
  const sidebarMenu = document.querySelector(".sidebar-menu");
  if (!sidebarMenu) return;
  
  sidebarMenu.innerHTML = "";
  
  // Group sections by their categories
  const categories = {};
  data.sections.forEach(section => {
    if (!categories[section.category]) {
      categories[section.category] = [];
    }
    categories[section.category].push(section);
  });
  
  // Generate HTML for each group
  Object.keys(categories).forEach(catName => {
    const group = document.createElement("div");
    group.className = "menu-group";
    
    const groupTitle = document.createElement("div");
    groupTitle.className = "menu-group-title";
    groupTitle.textContent = catName;
    group.appendChild(groupTitle);
    
    categories[catName].forEach((section) => {
      const menuItem = document.createElement("div");
      menuItem.className = `menu-item ${section.id === "sec-login" ? "active" : ""}`;
      menuItem.id = `menu-link-${section.id}`;
      menuItem.onclick = (e) => scrollToSection(section.id, menuItem);
      
      // Determine Icon based on section id
      let iconSvg = getMenuIconSvg(section.id);
      
      menuItem.innerHTML = `
        ${iconSvg}
        <span>${section.title.split(" - ")[0]}</span>
      `;
      
      group.appendChild(menuItem);
    });
    
    sidebarMenu.appendChild(group);
  });
}

function getMenuIconSvg(id) {
  const icons = {
    "sec-login": `<svg class="menu-item-icon" viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 16h2v-2h-2v2zm0-4h2V7h-2v5z"/></svg>`,
    "sec-permissions": `<svg class="menu-item-icon" viewBox="0 0 24 24"><path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm-2 16l-4-4 1.41-1.41L10 14.17l6.59-6.59L18 9l-8 8z"/></svg>`,
    "sec-sync": `<svg class="menu-item-icon" viewBox="0 0 24 24"><path d="M12 4V1L8 5l4 4V6c3.31 0 6 2.69 6 6 0 1.01-.25 1.97-.7 2.8l1.46 1.46C19.54 15.03 20 13.57 20 12c0-4.42-3.58-8-8-8zm-6 8c0-1.01.25-1.97.7-2.8L6.24 7.74C5.46 8.97 5 10.43 5 12c0 4.42 3.58 8 8 8v-3l4-4-4-4v3c-3.31 0-6-2.69-6-6z"/></svg>`,
    "sec-accepting-dispatch": `<svg class="menu-item-icon" viewBox="0 0 24 24"><path d="M20 8H4V6h16v2zm-2-6H6v2h12V2zm4 8v10c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V10c0-1.1.9-2 2-2h16c1.1 0 2 .9 2 2zm-2 2H4v8h16v-8z"/></svg>`,
    "sec-for-deliveries": `<svg class="menu-item-icon" viewBox="0 0 24 24"><path d="M12 2c-1.88 0-3.37 1.45-3.37 3.33 0 2.21 3.37 6.67 3.37 6.67s3.37-4.46 3.37-6.67C15.37 3.45 13.88 2 12 2zm0 4.5c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5 0.67 1.5 1.5-0.67 1.5-1.5 1.5zM12 14c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/></svg>`,
    "sec-update-deliveries": `<svg class="menu-item-icon" viewBox="0 0 24 24"><path d="M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zM20.71 7.04c.39-.39.39-1.02 0-1.41l-2.34-2.34c-.39-.39-1.02-.39-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z"/></svg>`,
    "sec-deliveries": `<svg class="menu-item-icon" viewBox="0 0 24 24"><path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-5 14H7v-2h7v2zm3-4H7v-2h10v2zm0-4H7V7h10v2z"/></svg>`,
    "sec-redelivery": `<svg class="menu-item-icon" viewBox="0 0 24 24"><path d="M12 4V1L8 5l4 4V6c3.31 0 6 2.69 6 6 0 1.01-.25 1.97-.7 2.8l1.46 1.46C19.54 15.03 20 13.57 20 12c0-4.42-3.58-8-8-8zm-6 8c0-1.01.25-1.97.7-2.8L6.24 7.74C5.46 8.97 5 10.43 5 12c0 4.42 3.58 8 8 8v-3l4-4-4-4v3c-3.31 0-6-2.69-6-6z"/></svg>`,
    "sec-misrouted": `<svg class="menu-item-icon" viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z"/></svg>`,
    "sec-bagsakan": `<svg class="menu-item-icon" viewBox="0 0 24 24"><path d="M4 6H2v14c0 1.1.9 2 2 2h14v-2H4V6zm16-4H8c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm0 12H8V4h12v12z"/></svg>`,
    "sec-wallet": `<svg class="menu-item-icon" viewBox="0 0 24 24"><path d="M21 18v1c0 1.1-.9 2-2 2H5c-1.11 0-2-.9-2-2V5c0-1.1.89-2 2-2h14c1.1 0 2 .9 2 2v1h-9c-1.11 0-2 .9-2 2v8c0 1.1.89 2 2 2h9zm-9-2h10V8H12v8zm4-2.5c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5z"/></svg>`,
    "sec-settings-update": `<svg class="menu-item-icon" viewBox="0 0 24 24"><path d="M19.14 12.94c.04-.3.06-.61.06-.94 0-.32-.02-.64-.07-.94l2.03-1.58c.18-.14.23-.41.12-.61l-1.92-3.32c-.12-.22-.37-.29-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54c-.04-.24-.24-.41-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.05.3-.09.63-.09.94s.02.64.07.94l-2.03 1.58c-.18.14-.23.41-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.62 3.6-3.6 3.6z"/></svg>`,
    "sec-change-password": `<svg class="menu-item-icon" viewBox="0 0 24 24"><path d="M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zM9 6c0-1.66 1.34-3 3-3s3 1.34 3 3v2H9V6zm9 14H6V10h12v10zm-6-3c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2z"/></svg>`,
    "sec-other": `<svg class="menu-item-icon" viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z"/></svg>`
  };
  return icons[id] || icons["sec-login"];
}

// ==========================================
// 3. RENDER MANUAL SECTIONS
// ==========================================
function renderManualContent(data) {
  const mainContent = document.querySelector(".main-content");
  if (!mainContent) return;
  
  mainContent.innerHTML = "";
  
  data.sections.forEach(section => {
    const docSec = document.createElement("section");
    docSec.className = "doc-section manual-section";
    docSec.id = section.id;
    
    // Core details
    let sectionHtml = `
      <span class="category-tag">${section.category}</span>
      <h2>${section.title}</h2>
      <p class="subtitle-lead">${section.lead}</p>
    `;
    
    // Adjust layout for columns if screenshot is present
    if (section.screenshot && section.steps) {
      sectionHtml += `
        <div class="two-column">
          <div>
            ${renderSteps(section.steps)}
          </div>
          <div>
            ${renderScreenshotPlaceholder(section.screenshot)}
          </div>
        </div>
      `;
    } else {
      // Normal single column renders
      if (section.steps) {
        sectionHtml += renderSteps(section.steps);
      }
      
      if (section.screenshot) {
        sectionHtml += renderScreenshotPlaceholder(section.screenshot);
      }
    }
    
    // Render Alert boxes
    if (section.alerts) {
      sectionHtml += renderAlerts(section.alerts);
    }
    
    // Render Feature Grids
    if (section.features) {
      sectionHtml += renderFeatureGrid(section.features);
    }
    
    // Render Subsections / Tabs
    if (section.tabs) {
      sectionHtml += renderTabsContainer(section.tabs);
    }
    
    docSec.innerHTML = sectionHtml;
    mainContent.appendChild(docSec);
  });
  
  // Append search error container at the bottom
  const noResultsDiv = document.createElement("div");
  noResultsDiv.className = "no-results";
  noResultsDiv.id = "no-results-msg";
  noResultsDiv.innerHTML = `
    <svg viewBox="0 0 24 24">
      <path d="M15.5 14h-.79l-.28-.27C15.41 12.59 16 11.11 16 9.5 16 5.91 13.09 3 9.5 3S3 5.91 3 9.5 5.91 16 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z"/>
    </svg>
    <h3>No matching guide found</h3>
    <p>Try searching for words like 'delivered', 'bagsakan', 'wallet', or 'password'.</p>
  `;
  mainContent.appendChild(noResultsDiv);
}

// Sub-renderers
function renderSteps(steps) {
  return `
    <ul class="step-list">
      ${steps.map(step => `
        <li class="step-item">
          <span class="step-number">${step.number}</span>
          <div class="step-title">${step.title}</div>
          <p>${step.text}</p>
        </li>
      `).join("")}
    </ul>
  `;
}

function renderScreenshotPlaceholder(ss) {
  return `
    <div class="screenshot-placeholder">
      <div class="placeholder-device-frame">
        <div class="placeholder-notch"></div>
        <div class="placeholder-content">
          <svg class="placeholder-icon" viewBox="0 0 24 24">
            <path d="M21 19V5c0-1.1-.9-2-2-2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2zM8.5 13.5l2.5 3.01L14.5 12l4.5 6H5l3.5-4.5z"/>
          </svg>
          <div class="placeholder-text">${ss.label.replace("📸 ", "")}</div>
          <div class="placeholder-dimensions">${ss.dimensions}</div>
        </div>
      </div>
      <div class="screenshot-label">${ss.label}</div>
    </div>
  `;
}

function renderAlerts(alerts) {
  return alerts.map(alert => {
    let alertIconSvg = `<svg class="alert-icon" viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z" fill="currentColor"/></svg>`;
    if (alert.type === "danger") {
      alertIconSvg = `<svg class="alert-icon" viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z" fill="currentColor"/></svg>`;
    }
    return `
      <div class="alert-box alert-box-${alert.type}">
        ${alertIconSvg}
        <div>${alert.text}</div>
      </div>
    `;
  }).join("");
}

function renderFeatureGrid(features) {
  return `
    <div class="feature-grid">
      ${features.map(feat => `
        <div class="feature-card">
          <div class="feature-card-title">
            <svg class="feature-card-icon" viewBox="0 0 24 24"><path d="M19.14 12.94c.04-.3.06-.61.06-.94s-.02-.64-.07-.94l2.03-1.58c.18-.14.23-.41.12-.61l-1.92-3.32c-.12-.22-.37-.29-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54c-.04-.24-.24-.41-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.05.3-.09.63-.09.94s.02.64.07.94l-2.03 1.58c-.18.14-.23.41-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.62 3.6-3.6 3.6z"/></svg>
            ${feat.title}
          </div>
          <p>${feat.text}</p>
        </div>
      `).join("")}
    </div>
  `;
}

function renderTabsContainer(tabs) {
  return `
    <div class="tab-container">
      <div class="tab-header">
        ${tabs.map((tab, idx) => `
          <button class="tab-btn ${idx === 0 ? "active" : ""}" onclick="switchTab(event, '${tab.tabId}')">${tab.tabBtnLabel}</button>
        `).join("")}
      </div>
      
      ${tabs.map((tab, idx) => `
        <div class="tab-content ${idx === 0 ? "active" : ""}" id="${tab.tabId}">
          <h3>${tab.title}</h3>
          <p>${tab.lead}</p>
          ${tab.steps ? renderSteps(tab.steps) : ""}
          ${tab.alerts ? renderAlerts(tab.alerts) : ""}
        </div>
      `).join("")}
    </div>
  `;
}

// ==========================================
// 4. INITIALIZE DOCUMENTATION VERSION SELECT
// ==========================================
function initVersionControl(data) {
  const footer = document.querySelector(".sidebar-footer");
  if (!footer) return;
  
  // Render version select in footer instead of static label
  footer.innerHTML = `
    <div class="version-select-container">
      <span class="version-tag">Ver:</span>
      <select class="version-select" id="version-select" onchange="handleVersionChange(this.value)" aria-label="Documentation Version">
        ${data.docHistory.map(hist => `
          <option value="${hist.version}" ${hist.version === 'v' + data.version ? 'selected' : ''}>${hist.version}</option>
        `).join("")}
      </select>
    </div>
    <button class="theme-toggle-btn" onclick="toggleTheme()" aria-label="Toggle Theme Mode">
      <svg class="menu-item-icon" id="theme-btn-icon" viewBox="0 0 24 24">
        <!-- Sun/Moon icon injected by theme init -->
      </svg>
    </button>
  `;

  // Create Modal overlay for changelogs dynamically
  const modalOverlay = document.createElement("div");
  modalOverlay.className = "modal-overlay";
  modalOverlay.id = "changelog-modal";
  modalOverlay.onclick = (e) => {
    if (e.target === modalOverlay) closeModal();
  };

  modalOverlay.innerHTML = `
    <div class="modal-card">
      <div class="modal-header">
        <div class="modal-title">Documentation Changelogs</div>
        <button class="modal-close-btn" onclick="closeModal()" aria-label="Close Dialog">&times;</button>
      </div>
      <div class="modal-body">
        ${data.docHistory.map(hist => `
          <div class="changelog-item">
            <div class="changelog-version-title">
              <span>${hist.version} (App ${hist.version.replace('v', '')})</span>
              <span class="changelog-date">${hist.date}</span>
            </div>
            <div class="changelog-text">${hist.changelog}</div>
          </div>
        `).join("")}
      </div>
    </div>
  `;

  document.body.appendChild(modalOverlay);
}

function handleVersionChange(val) {
  // Trigger changelog popup modal
  showModal();
}

function showModal() {
  const modal = document.getElementById("changelog-modal");
  if (!modal) return;
  modal.style.display = "flex";
  setTimeout(() => modal.classList.add("active"), 10);
}

function closeModal() {
  const modal = document.getElementById("changelog-modal");
  if (!modal) return;
  modal.classList.remove("active");
  setTimeout(() => {
    modal.style.display = "none";
    // Reset select to currently loaded version
    const select = document.getElementById("version-select");
    if (select) select.value = "v" + window.MANUAL_DATA.version;
  }, 250);
}

// ==========================================
// 5. INTERACTIVE CONTROLLER ACTIONS
// ==========================================

// Smooth Scrolling
function scrollToSection(id, element) {
  const target = document.getElementById(id);
  if (target) {
    target.scrollIntoView({ behavior: 'smooth' });
  }

  const menuItems = document.querySelectorAll('.menu-item');
  menuItems.forEach(item => item.classList.remove('active'));
  
  if (element) {
    element.classList.add('active');
  }

  const sidebar = document.getElementById('sidebar');
  if (window.innerWidth <= 1024) {
    sidebar.classList.remove('open');
  }
}

// Mobile sidebar trigger
function toggleMobileSidebar() {
  const sidebar = document.getElementById('sidebar');
  sidebar.classList.toggle('open');
}

// Section tab trigger
function switchTab(event, tabId) {
  const tabContainer = event.currentTarget.closest('.tab-container');
  
  const buttons = tabContainer.querySelectorAll('.tab-btn');
  const contents = tabContainer.querySelectorAll('.tab-content');
  
  buttons.forEach(btn => btn.classList.remove('active'));
  contents.forEach(content => content.classList.remove('active'));
  
  event.currentTarget.classList.add('active');
  tabContainer.querySelector('#' + tabId).classList.add('active');
}

// Theme management
function toggleTheme() {
  const body = document.body;
  body.classList.toggle('dark-theme');
  
  const isDark = body.classList.contains('dark-theme');
  localStorage.setItem('theme', isDark ? 'dark' : 'light');
  
  updateThemeIcon(isDark);
}

function updateThemeIcon(isDark) {
  const themeBtnIcon = document.getElementById('theme-btn-icon');
  if (!themeBtnIcon) return;
  
  if (isDark) {
    themeBtnIcon.innerHTML = '<path d="M12 7c-2.76 0-5 2.24-5 5s2.24 5 5 5 5-2.24 5-5-2.24-5-5-5zM2 13h2c.55 0 1-.45 1-1s-.45-1-1-1H2c-.55 0-1 .45-1 1s.45 1 1 1zm18 0h2c.55 0 1-.45 1-1s-.45-1-1-1h-2c-.55 0-1 .45-1 1s.45 1 1 1zM11 2v2c0 .55.45 1 1 1s1-.45 1-1V2c0-.55-.45-1-1-1s-1 .45-1 1zm0 18v2c0 .55.45 1 1 1s1-.45 1-1v-2c0-.55-.45-1-1-1s-1 .45-1 1zM5.99 4.58c-.39-.39-1.03-.39-1.41 0s-.39 1.03 0 1.41l1.06 1.06c.39.39 1.03.39 1.41 0s.39-1.03 0-1.41L5.99 4.58zm12.37 12.37c-.39-.39-1.03-.39-1.41 0s-.39 1.03 0 1.41l1.06 1.06c.39.39 1.03.39 1.41 0s.39-1.03 0-1.41l-1.06-1.06zm1.06-12.37c-.39-.39-1.03-.39-1.41 0l-1.06 1.06c-.39.39-.39 1.03 0 1.41s1.03.39 1.41 0l1.06-1.06c.39-.38.39-1.02 0-1.41zm-12.37 12.37c-.39-.39-1.03-.39-1.41 0l-1.06 1.06c-.39.39-.39 1.03 0 1.41s1.03.39 1.41 0l1.06-1.06c.39-.38.39-1.02 0-1.41z"/>';
  } else {
    themeBtnIcon.innerHTML = '<path d="M12.3 22h-.1c-5.5 0-10-4.5-10-10 0-4.8 3.5-8.9 8.2-9.8.6-.1 1.2.3 1.3.9.1.6-.2 1.2-.8 1.4-3.7.8-6.5 4.1-6.5 8 0 4.4 3.6 8 8 8 3.9 0 7.2-2.8 8-6.5.2-.6.7-.9 1.3-.8.6.1 1 .6.9 1.2-.9 4.7-5 8.2-9.8 8.2-.4 0-.8-.1-1.2-.2zm.9-2c3.4 0 6.4-2.1 7.5-5.3-.8.3-1.6.4-2.5.4-4.8 0-8.8-3.7-9.2-8.5C5.8 8.1 4.2 11.3 4.2 15c0 4.4 3.6 8 8 8 .4 0 .7 0 1-.1z"/>';
  }
}

function initTheme() {
  const cachedTheme = localStorage.getItem('theme');
  if (cachedTheme === 'dark' || (!cachedTheme && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
    document.body.classList.add('dark-theme');
    updateThemeIcon(true);
  } else {
    updateThemeIcon(false);
  }
}

// Live Search Filter
function filterManual() {
  const query = document.getElementById('search-box').value.toLowerCase().trim();
  const sections = document.querySelectorAll('.manual-section');
  const noResultsMsg = document.getElementById('no-results-msg');
  let matchesAny = false;

  sections.forEach(section => {
    const textContent = section.innerText.toLowerCase();
    
    if (query === '' || textContent.includes(query)) {
      section.style.display = 'block';
      matchesAny = true;
    } else {
      section.style.display = 'none';
    }
  });

  if (matchesAny) {
    noResultsMsg.style.display = 'none';
  } else {
    noResultsMsg.style.display = 'block';
  }
}

// Back to Top Button
window.onscroll = function() {
  const backToTopBtn = document.getElementById('btn-back-to-top');
  if (!backToTopBtn) return;
  
  if (document.body.scrollTop > 300 || document.documentElement.scrollTop > 300) {
    backToTopBtn.style.display = "flex";
  } else {
    backToTopBtn.style.display = "none";
  }
};

function scrollToTop() {
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

// ScrollSpy highlight sidebar items as user scrolls down
function initScrollSpy() {
  window.addEventListener("scroll", () => {
    const sections = document.querySelectorAll(".manual-section");
    const menuItems = document.querySelectorAll(".menu-item");
    
    let currentId = "sec-login";
    sections.forEach(section => {
      const sectionTop = section.offsetTop;
      if (pageYOffset >= sectionTop - 120) {
        currentId = section.id;
      }
    });
    
    menuItems.forEach(item => {
      item.classList.remove("active");
      if (item.id === `menu-link-${currentId}`) {
        item.classList.add("active");
      }
    });
  });
}
