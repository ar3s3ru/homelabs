# DHCP Lease Duration and DNS Configuration Strategy

## Context and Problem Statement

OpenWrt/dnsmasq serves both DHCP and DNS for the homelab network. Static DHCP reservations ensure devices receive consistent IP addresses, but DNS hostname resolution depends on either explicit configuration or DHCP lease activity. After router restarts, devices with infinite DHCP leases may not have DNS records until they actively renew their leases.

Key questions:
- How should DNS records be created for devices with static DHCP reservations?
- What lease duration balances reliability, DNS availability, and network efficiency?
- Should different device classes have different strategies?

## Decision Drivers

- **Reliability**: DNS resolution must work consistently for device hostnames
- **Single Source of Truth**: IP addresses should be defined once to avoid configuration drift
- **Operational Simplicity**: Minimize manual DNS entry management
- **Standard DHCP Behavior**: Prefer inheriting hostnames from devices rather than manual configuration

## Considered Options

1. **Static DHCP Reservation with Finite Lease Time** - Device renews DHCP periodically, DNS created automatically from DHCP hostname
2. **Static DHCP + Name Field (Hybrid)** - Add explicit hostname to DHCP reservation, DNS works immediately without active lease
3. **Separate Domain Entry** - Maintain DNS records separately from DHCP configuration
4. **No Static Reservation, Just Domain Entry** - Device uses static IP configuration, DNS managed manually

## Decision Outcome

Chosen option: **"Option 1: Static DHCP Reservation with Finite Lease Time"**, because it uses standard DHCP behavior where devices provide their own hostnames, maintains single source of truth for IP addresses, and provides acceptable DNS availability for homelab use cases.

### Lease Duration by Device Class

- **Regular IoT Devices** (cameras, sensors, smart devices): 12h lease time
  - Devices renew at ~6h (50% of lease time)
  - Maximum DNS outage window after router restart: 6h
  - IP address can be used as fallback during DNS outage

- **Servers/Nodes** (Kubernetes, Proxmox, NAS): Longer lease time
  - These devices rarely restart and stay online continuously
  - Extended lease reduces DHCP renewal traffic

### Consequences

#### Positive

- Single source of truth: IP addresses defined once in DHCP configuration
- DNS automatically created from device's DHCP hostname option
- Standard DHCP behavior, no custom configuration required
- Acceptable DNS outage window (6h max) for regular devices
- Reduced configuration complexity vs maintaining separate DNS entries

#### Negative

- DNS records unavailable immediately after router restart until device renews lease
- Temporary DNS outage window (up to 6h for 12h leases)
- Requires devices to send correct hostname in DHCP requests
- Must use IP addresses as fallback during DNS outage periods

## Pros and Cons of the Options

### Option 1: Static DHCP Reservation with Finite Lease Time

- Good, because IP address defined once in UCI configuration
- Good, because DNS automatically created when device renews lease
- Good, because uses standard DHCP behavior
- Good, because hostname inherited from device
- Bad, because DNS only works after first renewal following router restart
- Bad, because temporary DNS outage window (up to 50% of lease time)
- Bad, because relies on device sending correct hostname in DHCP request

### Option 2: Static DHCP + Name Field (Hybrid)

- Good, because IP address defined once in UCI configuration
- Good, because DNS works immediately after router restart
- Good, because no dependency on device behavior
- Good, because maximum DNS reliability
- Bad, because hostname must be specified in router configuration
- Bad, because two potential sources of hostname (device vs router)
- Bad, because hostname mismatch if device changes its name

### Option 3: Separate Domain Entry

- Good, because DNS works immediately and reliably
- Good, because works for devices with static IP configuration
- Good, because full control over DNS names
- Bad, because IP address defined in two places (DHCP host + domain entry)
- Bad, because risk of configuration inconsistency
- Bad, because violates DRY principle

### Option 4: No Static Reservation, Just Domain Entry

- Good, because single source of truth for IP (device's static config)
- Good, because DNS always works
- Good, because simpler router configuration
- Bad, because IP configured in device firmware (harder to change)
- Bad, because no DHCP options provided to device
- Bad, because IP not visible in router's DHCP overview
- Bad, because less centralized management
