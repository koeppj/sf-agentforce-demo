import fs from "node:fs/promises";
import path from "node:path";
import { getSlides } from "@office-kit/pptx";
import { loadPresentationFile } from "@office-kit/pptx/node";
import { auditTextLayout } from "@office-kit/pptx-preview";
import { buildFontkitMeasurer, renderSlideToImage } from "@office-kit/pptx-preview/node";

const root = path.resolve("..");
const input = path.join(root, "build", "hr-request-portal-business-overview-candidate.pptx");
const outDir = path.join(root, "preview");
await fs.mkdir(outDir, { recursive: true });

const presentation = await loadPresentationFile(input);
const slides = getSlides(presentation);
for (let index = 0; index < slides.length; index += 1) {
  const png = renderSlideToImage(presentation, slides[index], { width: 1600 });
  await fs.writeFile(path.join(outDir, `slide-${index + 1}.png`), png);
}

const measureText = buildFontkitMeasurer({
  fonts: [
    { family: "Inter", source: "/Library/Fonts/Inter-Regular.ttf" },
    { family: "Inter SemiBold", source: "/Library/Fonts/Inter-SemiBold.ttf" },
  ],
});
const issues = auditTextLayout(presentation, {
  measureText,
  reportSoftWraps: false,
  tolerancePx: 2,
});
await fs.writeFile(path.join(outDir, "text-layout-audit.json"), `${JSON.stringify(issues, null, 2)}\n`);
console.log(JSON.stringify({ slideCount: slides.length, issues }, null, 2));
