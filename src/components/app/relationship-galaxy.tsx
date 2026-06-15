"use client";

import { useEffect, useMemo, useRef, useState, type CSSProperties } from "react";
import * as THREE from "three";

import type { DashboardRelationshipGraph } from "@/data/demo";

type Props = {
  graph: DashboardRelationshipGraph;
};

export function RelationshipGalaxy({ graph }: Props) {
  const hostRef = useRef<HTMLDivElement | null>(null);
  const [hovered, setHovered] = useState<string | null>(null);
  const [fallback, setFallback] = useState(false);
  const galaxyNodes = useMemo(() => layoutGalaxyNodes(graph), [graph]);

  useEffect(() => {
    const host = hostRef.current;
    if (!host) return;
    const hostElement = host;

    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (reducedMotion) {
      const fallbackFrame = window.requestAnimationFrame(() => setFallback(true));
      return () => window.cancelAnimationFrame(fallbackFrame);
    }

    let renderer: THREE.WebGLRenderer;
    try {
      renderer = new THREE.WebGLRenderer({
        alpha: true,
        antialias: true,
        preserveDrawingBuffer: true,
      });
    } catch {
      const fallbackFrame = window.requestAnimationFrame(() => setFallback(true));
      return () => window.cancelAnimationFrame(fallbackFrame);
    }

    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(44, 1, 0.1, 100);
    camera.position.set(0, 1.05, 6.4);
    camera.lookAt(0, 0, 0);

    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.setClearColor(0x000000, 0);
    hostElement.appendChild(renderer.domElement);

    const root = new THREE.Group();
    scene.add(root);

    const ambient = new THREE.AmbientLight(0xffffff, 2.2);
    scene.add(ambient);
    const point = new THREE.PointLight(0xf5fff9, 3.4, 20);
    point.position.set(0, 2, 4);
    scene.add(point);

    const meMaterial = new THREE.MeshStandardMaterial({
      color: 0xffffff,
      emissive: 0x78d4a2,
      emissiveIntensity: 0.42,
      roughness: 0.36,
    });
    const me = new THREE.Mesh(new THREE.SphereGeometry(0.4, 40, 40), meMaterial);
    me.userData = { label: graph.me.name };
    root.add(me);

    const lineMaterial = new THREE.LineBasicMaterial({
      color: 0x9eb5aa,
      transparent: true,
      opacity: 0.8,
    });
    const pickable: THREE.Object3D[] = [me];

    graph.groups.forEach((group) => {
      const ring = new THREE.Mesh(
        new THREE.TorusGeometry(1.45 + group.orbit * 0.62, 0.006, 8, 96),
        new THREE.MeshBasicMaterial({
          color: colorToNumber(group.color),
          transparent: true,
          opacity: 0.34,
        }),
      );
      ring.rotation.x = Math.PI / 2.4;
      root.add(ring);
    });

    graph.nodes.forEach((node, index) => {
      const group = graph.groups.find((item) => item.id === node.groupId);
      const layout = galaxyNodes[index];
      const radius = 1.55 + layout.orbit * 0.62 + (1 - node.strength) * 0.34;
      const angle = (layout.angle / 180) * Math.PI;
      const z = Math.sin(angle * 1.7) * 0.5;
      const x = Math.cos(angle) * radius;
      const y = Math.sin(angle) * radius * 0.52;
      const nodeMesh = new THREE.Mesh(
        new THREE.SphereGeometry(0.16 + node.strength * 0.14, 24, 24),
        new THREE.MeshStandardMaterial({
          color: colorToNumber(group?.color || "#256f56"),
          emissive: colorToNumber(group?.color || "#256f56"),
          emissiveIntensity: 0.28 + node.strength * 0.34,
          roughness: 0.32,
        }),
      );
      nodeMesh.position.set(x, y, z);
      nodeMesh.userData = { label: `${node.label} · ${node.score}` };
      root.add(nodeMesh);
      pickable.push(nodeMesh);

      const line = new THREE.Line(
        new THREE.BufferGeometry().setFromPoints([
          new THREE.Vector3(0, 0, 0),
          new THREE.Vector3(x, y, z),
        ]),
        lineMaterial,
      );
      root.add(line);

      if (node.hasUpcoming || node.hasBirthday) {
        const halo = new THREE.Mesh(
          new THREE.TorusGeometry(0.28 + node.strength * 0.06, 0.01, 8, 42),
          new THREE.MeshBasicMaterial({
            color: node.hasUpcoming ? 0xd7a95b : 0xeac9d8,
            transparent: true,
            opacity: 0.8,
          }),
        );
        halo.position.copy(nodeMesh.position);
        halo.rotation.x = Math.PI / 2;
        root.add(halo);
      }
    });

    const raycaster = new THREE.Raycaster();
    const pointer = new THREE.Vector2();
    let frame = 0;

    function resize() {
      const rect = hostElement.getBoundingClientRect();
      renderer.setSize(rect.width, rect.height, false);
      camera.aspect = rect.width / Math.max(1, rect.height);
      camera.updateProjectionMatrix();
    }

    function handlePointerMove(event: PointerEvent) {
      const rect = renderer.domElement.getBoundingClientRect();
      pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
      pointer.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;
      raycaster.setFromCamera(pointer, camera);
      const hit = raycaster.intersectObjects(pickable, false)[0];
      setHovered(typeof hit?.object.userData.label === "string" ? hit.object.userData.label : null);
    }

    function animate() {
      frame = window.requestAnimationFrame(animate);
      root.rotation.y += 0.0028;
      root.rotation.x = Math.sin(Date.now() / 4200) * 0.045;
      renderer.render(scene, camera);
    }

    resize();
    animate();
    renderer.domElement.addEventListener("pointermove", handlePointerMove);
    window.addEventListener("resize", resize);

    return () => {
      window.cancelAnimationFrame(frame);
      renderer.domElement.removeEventListener("pointermove", handlePointerMove);
      window.removeEventListener("resize", resize);
      renderer.dispose();
      hostElement.replaceChildren();
    };
  }, [galaxyNodes, graph]);

  if (fallback) {
    return <GalaxyFallback graph={graph} />;
  }

  return (
    <div className="relative min-h-[460px] overflow-hidden rounded-lg border border-white/10 bg-[radial-gradient(circle_at_50%_45%,#1f543f_0%,#10231f_42%,#07110f_100%)]">
      <GalaxyVisibleLayer graph={graph} nodes={galaxyNodes} />
      <div ref={hostRef} className="absolute inset-0 z-10 opacity-90 mix-blend-screen" aria-label="3D relationship galaxy" />
      <div className="pointer-events-none absolute left-4 top-4 rounded-md border border-white/10 bg-black/20 px-3 py-2 text-xs text-[#dcebe3] backdrop-blur">
        {hovered || `${graph.me.name} 是中心，越亮越需要关注`}
      </div>
      <div className="pointer-events-none absolute inset-x-4 bottom-4 grid gap-2 sm:grid-cols-3">
        {graph.nodes.slice(0, 3).map((node) => (
          <div key={node.id} className="rounded-md border border-white/10 bg-black/25 px-3 py-2 text-xs text-[#e8f4ee] backdrop-blur">
            <p className="font-semibold">{node.label}</p>
            <p className="mt-0.5 text-[#b9cdc4]">{node.groupLabel} · {node.score}</p>
          </div>
        ))}
      </div>
    </div>
  );
}

type GalaxyNodeLayout = DashboardRelationshipGraph["nodes"][number] & {
  angle: number;
  orbit: number;
  x: number;
  y: number;
};

function GalaxyVisibleLayer({
  graph,
  nodes,
}: {
  graph: DashboardRelationshipGraph;
  nodes: GalaxyNodeLayout[];
}) {
  return (
    <div className="absolute inset-0 z-0" aria-hidden="true">
      <svg className="absolute inset-0 h-full w-full" viewBox="0 0 100 100" preserveAspectRatio="none">
        <defs>
          <radialGradient id="relationship-galaxy-node" cx="45%" cy="35%" r="70%">
            <stop offset="0%" stopColor="#ffffff" stopOpacity="0.95" />
            <stop offset="45%" stopColor="#b9f2cf" stopOpacity="0.62" />
            <stop offset="100%" stopColor="#236044" stopOpacity="0.2" />
          </radialGradient>
        </defs>
        {graph.groups.map((group) => (
          <ellipse
            key={group.id}
            cx="50"
            cy="48"
            rx={18 + group.orbit * 8}
            ry={9 + group.orbit * 4.3}
            fill="none"
            stroke={group.color}
            strokeDasharray="1.2 1.8"
            strokeOpacity="0.44"
            strokeWidth="0.35"
          />
        ))}
        {nodes.map((node) => (
          <line
            key={`${node.id}-visible-edge`}
            x1="50"
            y1="48"
            x2={node.x}
            y2={node.y}
            stroke="#dcebe3"
            strokeOpacity={0.22 + node.strength * 0.42}
            strokeWidth={0.22 + node.strength * 0.46}
          />
        ))}
      </svg>
      <div className="absolute left-1/2 top-[48%] grid h-20 w-20 -translate-x-1/2 -translate-y-1/2 place-items-center rounded-full border border-white/50 bg-white text-sm font-semibold text-[#10231f] shadow-[0_0_42px_rgba(126,224,167,0.78)]">
        {graph.me.initials}
      </div>
      {nodes.map((node) => (
        <div
          key={`${node.id}-visible-node`}
          className="absolute grid -translate-x-1/2 -translate-y-1/2 place-items-center rounded-full border border-white/45 text-xs font-semibold text-white"
          style={
            {
              left: `${node.x}%`,
              top: `${node.y}%`,
              width: `${34 + node.strength * 18}px`,
              height: `${34 + node.strength * 18}px`,
              background: `radial-gradient(circle at 35% 30%, #ffffff 0%, ${nodeColor(graph, node)} 38%, #10231f 100%)`,
              boxShadow: `0 0 ${18 + node.score / 3}px ${nodeColor(graph, node)}88`,
            } as CSSProperties
          }
        >
          {node.initials}
          {(node.hasBirthday || node.hasUpcoming) && (
            <span className="absolute -right-1 -top-1 h-3 w-3 rounded-full border border-[#07110f] bg-[#e6c56c] shadow-[0_0_18px_rgba(230,197,108,0.85)]" />
          )}
        </div>
      ))}
    </div>
  );
}

function GalaxyFallback({ graph }: Props) {
  return (
    <div className="min-h-[360px] rounded-lg bg-[#0c1b18] p-5 text-[#dcebe3]">
      <div className="flex items-center justify-between">
        <p className="text-sm font-semibold">{graph.me.name} 的关系星图</p>
        <p className="text-xs text-[#9eb5aa]">2D 可读版</p>
      </div>
      <div className="mt-5 grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
        {graph.nodes.map((node) => (
          <div key={node.id} className="rounded-md border border-white/10 bg-white/[0.04] p-3">
            <div className="flex items-center justify-between">
              <span className="font-medium">{node.label}</span>
              <span className="text-xs text-[#f0c36a]">{node.score}</span>
            </div>
            <p className="mt-1 text-xs text-[#9eb5aa]">{node.groupLabel}</p>
            <p className="mt-2 text-xs leading-5 text-[#c9d8d0]">{node.lastSignal}</p>
          </div>
        ))}
      </div>
    </div>
  );
}

function colorToNumber(color: string) {
  return Number.parseInt(color.replace("#", ""), 16);
}

function layoutGalaxyNodes(graph: DashboardRelationshipGraph): GalaxyNodeLayout[] {
  const groupCounts = new Map<string, number>();

  return graph.nodes.map((node) => {
    const group = graph.groups.find((item) => item.id === node.groupId);
    const groupIndex = Math.max(
      0,
      graph.groups.findIndex((item) => item.id === node.groupId),
    );
    const count = groupCounts.get(node.groupId) || 0;
    groupCounts.set(node.groupId, count + 1);

    const angle =
      (count / Math.max(1, group?.memberCount || 1)) * 360 +
      groupIndex * 72 -
      94;
    const orbit = group?.orbit || groupIndex + 1;
    const distance = 18 + orbit * 8 + (1 - node.strength) * 5;
    const radians = (angle / 180) * Math.PI;

    return {
      ...node,
      angle,
      orbit,
      x: 50 + Math.cos(radians) * distance,
      y: 48 + Math.sin(radians) * distance * 0.5,
    };
  });
}

function nodeColor(graph: DashboardRelationshipGraph, node: GalaxyNodeLayout) {
  return graph.groups.find((group) => group.id === node.groupId)?.color || "#256f56";
}
