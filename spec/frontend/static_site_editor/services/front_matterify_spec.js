import {
  sourceContentYAML as content,
  sourceContentHeaderObjYAML as yamlFrontMatterObj,
  sourceContentSpacing as spacing,
  sourceContentBody as body,
} from '../mock_data';

import { frontMatterify, stringify } from '~/static_site_editor/services/front_matterify';

describe('static_site_editor/services/front_matterify', () => {
  const frontMatterifiedContent = {
    source: content,
    matter: yamlFrontMatterObj,
    spacing,
    content: body,
    delimiter: '---',
    type: 'yaml',
  };
  const frontMatterifiedBody = {
    source: body,
    matter: null,
    spacing: null,
    content: body,
    delimiter: null,
    type: null,
  };

  describe('frontMatterify', () => {
    it.each`
      frontMatterified           | target
      ${frontMatterify(content)} | ${frontMatterifiedContent}
      ${frontMatterify(body)}    | ${frontMatterifiedBody}
    `('returns $target from $frontMatterified', ({ frontMatterified, target }) => {
      expect(frontMatterified).toEqual(target);
    });
  });

  describe('stringify', () => {
    it.each`
      stringified                           | target
      ${stringify(frontMatterifiedContent)} | ${content}
      ${stringify(frontMatterifiedBody)}    | ${body}
    `('returns $target from $stringified', ({ stringified, target }) => {
      expect(stringified).toBe(target);
    });
  });
});
